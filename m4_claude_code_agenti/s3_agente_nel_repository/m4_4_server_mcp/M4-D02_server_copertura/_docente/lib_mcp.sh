# shellcheck shell=bash
# =====================================================================
# lib_mcp.sh -- di _docente/live.sh di M4-D02: le due configurazioni MCP
# e le chiamate claude -p in stream-json
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh; non si esegue.
#
# mcp::configurazioni scrive con.json, che dichiara il server del corso con
# i percorsi assoluti (un percorso relativo nel comando o negli argomenti
# di un server si risolverebbe dalla cartella in cui parte Claude Code) e
# con uv run --frozen (uv usa uv.lock così com'è, senza riscriverlo), e
# senza.json, che non ne dichiara nessuno. live.sh le scrive in una
# cartella fuori dallo spazio di lavoro.
# handson::claude_p scrive sempre --output-format json, mentre qui serve lo
# stream-json (solo lì si vedono i server dell'evento init e gli strumenti
# chiamati): mcp::chiedi compone la stessa riga di handson::claude_p con
# --output-format stream-json --verbose e la configurazione del braccio,
# dopo gli stessi controlli della libreria (mcp::controlli), e la esegue
# senza ANTHROPIC_API_KEY; la riga si vede prima di girare (handson::run).
# Le stesse opzioni per i due bracci: Sonnet, effort low, il solo strumento
# integrato Read (--tools Read: in dontAsk la sessione legge soltanto lo
# spazio di lavoro, e lo strumento del server resta, perché --tools non
# riguarda gli strumenti MCP), il solo strumento del server consentito,
# --strict-mcp-config, nessuna sessione salvata.
#
# Le due esecuzioni di una coppia non devono vedere l'una la risposta
# dell'altra: mcp::spazio_pulito pretende uno spazio di lavoro con soltanto
# domanda.txt, .claude/ e .git, e mcp::cartella_fuori crea, sotto /tmp, la
# cartella dove stanno le configurazioni e gli stream finché le sei
# esecuzioni non sono finite.
#
# Globals (lette): HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES, di
#   tools/lib_handson.sh; (aggiunta) HANDSON_TMPDIRS, i suoi temporanei.
# =====================================================================

readonly MCP_MODELLO=sonnet
readonly MCP_STRUMENTO=mcp__copertura__cerca_copertura
readonly MCP_OPZIONI=(--tools Read --effort low --strict-mcp-config
  --no-session-persistence)

# I controlli della libreria sulla riga di claude: modello, prompt,
# modalità di permesso, argomenti vietati, chiavi API. Fuori da $(…): una
# precondizione esce davvero con 2. Arguments: $1 il prompt.
mcp::controlli() {
  local arg
  handson::_claude_p_checks "${MCP_MODELLO}" "$1"
  handson::_claude_key_ok "$1"
  for arg in "${MCP_MODELLO}" "${MCP_STRUMENTO}" "${MCP_OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
}

# Lo spazio di lavoro (la cartella corrente) ha soltanto domanda.txt,
# .claude/ e .git: nient'altro che una sessione possa leggere, come le
# risposte o le configurazioni di una prova precedente. Altrimenti esce 2.
mcp::spazio_pulito() {
  local f nome
  local -a altro=()
  for f in ./* ./.[!.]* ./..?*; do
    [[ -e "${f}" || -L "${f}" ]] || continue
    nome="${f#./}"
    case "${nome}" in
      domanda.txt|.claude|.git) ;;
      *) altro+=("${nome}") ;;
    esac
  done
  if (( ${#altro[@]} > 0 )); then
    handson::die "lo spazio di lavoro deve avere soltanto domanda.txt e" \
      ".claude/ (c'è anche: ${altro[*]}): tools/reset_esercizio.sh M4-D02" \
      "lo prepara di nuovo"
  fi
}

# Una cartella nuova sotto /tmp, fuori dallo spazio di lavoro, con mcp/ e
# risposte/: sotto /tmp, così a schermo non compare la cartella di casa. Si
# toglie all'uscita con i temporanei della libreria (handson::cleanup, come
# le cartelle di handson::tmpdir). Va chiamata fuori da $(…).
# Globals: HANDSON_TMPDIRS (vi aggiunge). Arguments: $1 il nome della
# variabile da assegnare con il percorso.
mcp::cartella_fuori() {
  local __f
  __f="$(mktemp -d /tmp/m4-d02.XXXXXX)" \
    || handson::die "mktemp non riesce a creare una cartella in /tmp"
  HANDSON_TMPDIRS+=("${__f}")
  trap handson::cleanup EXIT
  mkdir -p -- "${__f}/mcp" "${__f}/risposte"
  printf -v "$1" '%s' "${__f}"
}

# Le due configurazioni MCP, con.json e senza.json, scritte da Python, che
# quota il JSON da sé. Arguments: $1 la cartella del server (assoluta), $2
# la cartella dei dati (assoluta), $3 la cartella dove scriverle.
mcp::configurazioni() {
  mkdir -p -- "$3"
  python3 -B -I - "$1" "$2" "$3" <<'PY'
import json, os, sys
server, dati, cartella = sys.argv[1:4]
con = {"mcpServers": {"copertura": {
    "type": "stdio", "command": "uv",
    "args": ["run", "--frozen", "--directory", server,
             "server_copertura.py"],
    "env": {"COPERTURA_DATI": dati}}}}
for nome, doc in (("con", con), ("senza", {"mcpServers": {}})):
    with open(os.path.join(cartella, nome + ".json"), "w",
              encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
PY
}

# Una chiamata, con il suo stream-json in un file: la riga di
# handson::claude_p con --output-format stream-json --verbose e la
# configurazione MCP del braccio, senza ANTHROPIC_API_KEY. Gira nella
# cartella corrente, lo spazio di lavoro.
# Arguments: $1 il file della configurazione, $2 il prompt, $3 il file
# dello stream. Returns: l'uscita di claude.
mcp::chiedi() {
  local -a argv=(claude -p --allowedTools "${MCP_STRUMENTO}"
    --model "${MCP_MODELLO}" --permission-mode "${HANDSON_PERMISSION_MODE}"
    --permission-prompts none --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}"
    --mcp-config "$1" "${MCP_OPZIONI[@]}" -- "$2")
  (
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
      handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
        "comando, così Claude Code usa l'abbonamento"
    fi
    unset ANTHROPIC_API_KEY
    handson::run "${argv[@]}" < /dev/null > "$3"
  )
}
