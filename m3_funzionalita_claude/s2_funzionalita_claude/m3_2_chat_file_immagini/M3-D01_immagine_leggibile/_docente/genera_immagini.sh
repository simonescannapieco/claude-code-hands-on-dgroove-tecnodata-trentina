#!/bin/bash
#
# genera_immagini.sh di M3-D01 -- le due immagini della demo, dalla stessa
# pagina demo/allarmi.html, con Chromium o Chrome senza interfaccia
# (headless). Serve al docente: i partecipanti trovano le due immagini già
# nel repository.
#   allarmi.png          1600×1000, la pagina così com'è;
#   allarmi-piccola.png  160×100, la stessa pagina impaginata a 1600×1000 e
#                        rimpicciolita dieci volte: un iframe con
#                        transform: scale(0.1) in una finestra di 160×100.
#                        --force-device-scale-factor=0.1 non basta: provato
#                        il 2026-10-21 con Chromium 149 e Chrome 155, dà
#                        800×500.
# Stesso contenuto, stesse proporzioni: le due immagini differiscono solo
# nella grandezza. Nascono in una cartella temporanea; se ne controllano le
# dimensioni nell'intestazione PNG e, solo se tutte e due tornano,
# prendono il posto di quelle vecchie.
#
# Uso:    _docente/genera_immagini.sh [<cartella d'uscita>]
#           default: la cartella demo/ dell'elemento
# Env:    PN_BROWSER  il browser (default: il primo che c'è fra chromium,
#                     chromium-browser, google-chrome, google-chrome-stable)
# Uscita: 0 = le due immagini, delle dimensioni attese · 1 = un'immagine
#         che il browser non ha scritto o di dimensioni diverse (le vecchie
#         restano) · 2 = precondizione: argomenti, cartella d'uscita
#         assente, allarmi.html o python3 che mancano, nessun browser, il
#         browser che esce con un errore
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly PAGINA="${SELF%/_docente/*}/demo/allarmi.html"
readonly BROWSER_NOTI=(chromium chromium-browser google-chrome
  google-chrome-stable)
readonly GRANDE='allarmi.png 1600 1000'
readonly PICCOLA='allarmi-piccola.png 160 100'
TMP=''

err() { echo "genera_immagini.sh: $*" >&2; }

# Toglie la cartella temporanea (mai vuota, / o un collegamento).
cleanup() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && -d "${TMP}" && ! -L "${TMP}" ]]
  then
    rm -rf -- "${TMP}"
  fi
}

# Il browser: PN_BROWSER, o il primo dei BROWSER_NOTI nel PATH.
# Outputs: il suo percorso. Returns: 0; 2 se non ce n'è uno.
trova_browser() {
  local b
  if [[ -n "${PN_BROWSER:-}" ]]; then
    if ! command -v -- "${PN_BROWSER}"; then
      err "PN_BROWSER non c'è: ${PN_BROWSER}"
      return 2
    fi
    return 0
  fi
  for b in "${BROWSER_NOTI[@]}"; do
    if command -v -- "${b}"; then
      return 0
    fi
  done
  err "nessun browser: serve uno fra ${BROWSER_NOTI[*]} (o PN_BROWSER)"
  return 2
}

# La pagina che contiene allarmi.html rimpicciolita dieci volte.
# Arguments: $1 il file da scrivere, accanto alla copia di allarmi.html.
scrivi_cornice() {
  printf '%s\n' '<!doctype html>' '<html><head><meta charset="utf-8">' \
    '<style>html, body { margin: 0; width: 160px; height: 100px;' \
    'overflow: hidden; background: #ffffff; } iframe { border: 0;' \
    'width: 1600px; height: 1000px; transform: scale(0.1);' \
    'transform-origin: 0 0; }</style></head><body>' \
    '<iframe src="allarmi.html" scrolling="no"></iframe></body></html>' \
    > "$1"
}

# Una schermata del browser senza interfaccia.
# Arguments: $1 il browser, $2 la pagina (percorso assoluto), $3 la
#   larghezza, $4 l'altezza, $5 il PNG da scrivere.
# Returns: 0; 2 (con le ultime righe del browser) se il browser fallisce.
scatta() {
  local -a argv=("$1" --headless --disable-gpu --hide-scrollbars
    --no-first-run --no-default-browser-check --mute-audio
    "--user-data-dir=${TMP}/profilo" "--window-size=$3,$4"
    --force-device-scale-factor=1 "--screenshot=$5" "file://${2// /%20}")
  if command -v timeout > /dev/null 2>&1; then
    argv=(timeout 120 "${argv[@]}")
  fi
  if ! "${argv[@]}" > "${TMP}/browser.log" 2>&1; then
    err "il browser è uscito con un errore (${5##*/}):"
    tail -n 5 -- "${TMP}/browser.log" >&2
    return 2
  fi
}

# Le dimensioni di un PNG, dall'intestazione IHDR.
# Arguments: $1 il file. Outputs: «larghezza altezza».
# Returns: 0; 1 se non c'è o non è un PNG.
dimensioni() {
  python3 -B -I - "$1" <<'PY'
import struct
import sys
try:
    with open(sys.argv[1], "rb") as fh:
        testa = fh.read(24)
except OSError:
    sys.exit(1)
if testa[:8] != b"\x89PNG\r\n\x1a\n" or testa[12:16] != b"IHDR":
    sys.exit(1)
print("%d %d" % struct.unpack(">II", testa[16:24]))
PY
}

# Controlla un'immagine appena scritta. Arguments: $1 «nome larghezza
# altezza». Outputs: l'esito. Returns: 0 se torna; 1 altrimenti.
controlla() {
  local nome lato_x lato_y trovate
  read -r nome lato_x lato_y <<< "$1"
  if ! trovate="$(dimensioni "${TMP}/${nome}")"; then
    echo "${nome}: il browser non ha scritto un PNG"
    return 1
  fi
  if [[ "${trovate}" != "${lato_x} ${lato_y}" ]]; then
    echo "${nome}: ${trovate/ /×}, attese ${lato_x}×${lato_y}"
    return 1
  fi
  echo "${nome}: ${lato_x}×${lato_y}"
}

main() {
  local uscita="${1:-${SELF%/_docente/*}/demo}" browser esito=0 voce
  if (( $# > 1 )); then
    err "uso: _docente/genera_immagini.sh [<cartella d'uscita>]"
    exit 2
  fi
  [[ -d "${uscita}" ]] \
    || { err "cartella d'uscita assente: ${uscita}"; exit 2; }
  [[ -f "${PAGINA}" && -r "${PAGINA}" ]] \
    || { err "manca la pagina ${PAGINA}"; exit 2; }
  command -v python3 > /dev/null 2>&1 || { err "manca python3"; exit 2; }
  browser="$(trova_browser)" || exit 2
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/m3d01_immagini.XXXXXX")" \
    || { err "mktemp non riesce"; exit 2; }
  trap cleanup EXIT
  cp -- "${PAGINA}" "${TMP}/allarmi.html"
  scrivi_cornice "${TMP}/cornice.html"
  scatta "${browser}" "${TMP}/allarmi.html" 1600 1000 "${TMP}/allarmi.png" \
    || exit 2
  scatta "${browser}" "${TMP}/cornice.html" 160 100 \
    "${TMP}/allarmi-piccola.png" || exit 2
  for voce in "${GRANDE}" "${PICCOLA}"; do
    controlla "${voce}" || esito=1
  done
  if (( esito != 0 )); then
    err "immagini non sostituite: le vecchie restano in ${uscita}"
    exit 1
  fi
  mv -f -- "${TMP}/allarmi.png" "${TMP}/allarmi-piccola.png" "${uscita}/"
  echo "Scritte in ${uscita}: allarmi.png e allarmi-piccola.png."
}

main "$@"
