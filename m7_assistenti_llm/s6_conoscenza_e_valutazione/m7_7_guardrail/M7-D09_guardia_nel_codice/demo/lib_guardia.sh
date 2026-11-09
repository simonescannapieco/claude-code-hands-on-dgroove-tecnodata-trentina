# shellcheck shell=bash
#
# lib_guardia.sh -- le parti di in_classe.sh di M7-D09 che preparano un'esecuzione:
# il system prompt e la richiesta di un braccio, la configurazione MCP con il
# server del banco, la copia della cartella con il suo .claude/settings.json.
# Si fa source da in_classe.sh; i globali elencati nelle funzioni li definisce
# in_classe.sh.

# Il system prompt di un braccio. Arguments: $1 il braccio.
system_di() {
  case "$1" in
    divieto-nel-prompt) printf '%s' system-prompt-divieto.md ;;
    *) printf '%s' system-prompt.md ;;
  esac
}

# La richiesta di un braccio. Arguments: $1 il braccio.
richiesta_di() {
  case "$1" in
    hook-post) printf '%s' richiesta-scheda.txt ;;
    hook-prompt) printf '%s' richiesta-bloccata.txt ;;
    *) printf '%s' richiesta-accredito.txt ;;
  esac
}

# La configurazione MCP di un'esecuzione, con il registro del server nel
# deposito. Globals: WS, SERVER, SCENARIO, KB, AMBIENTE_UV.
# Arguments: $1 il file da scrivere, $2 il registro.
scrivi_mcp() {
  python3 -B -I - "$1" "$2" "${WS}/${SERVER}" "${WS}/${SCENARIO}" \
    "${WS}/${KB}" "${WS}/strumenti.json" "${AMBIENTE_UV}" <<'PY'
import json, sys
destinazione, registro, server, scenario, kb, strumenti, ambiente = sys.argv[1:8]
config = {"mcpServers": {"assistenza": {
    "command": "uv",
    "args": ["run", "--frozen", "--quiet", "--directory", server,
             "server_banco.py"],
    "env": {"BANCO_SCENARIO": scenario, "BANCO_KB": kb,
            "BANCO_STRUMENTI": strumenti, "BANCO_REGISTRO": registro,
            "UV_PROJECT_ENVIRONMENT": ambiente,
            "FASTMCP_CHECK_FOR_UPDATES": "off"}}}}
with open(destinazione, "w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=1)
PY
}

# La copia di un'esecuzione: .claude/settings.json del braccio e i tre hook, un
# repository git con un commit. Globals: COPIE, ELEMENTO; COPIA (assegnata).
# Arguments: $1 il braccio, $2 il nome dell'esecuzione.
nuova_copia() {
  # shellcheck disable=SC2153  # COPIE la assegna in_classe.sh
  COPIA="${COPIE}/$2"
  mkdir -p -- "${COPIA}/.claude/hooks" \
    || handson::die "non riesco a creare ${COPIA}"
  cp -- "bracci/$1.json" "${COPIA}/.claude/settings.json" \
    || handson::die "non riesco a copiare bracci/$1.json"
  cp -- hook/blocca_accredito.sh hook/blocca_prompt.sh \
    hook/maschera_telefono.py "${COPIA}/.claude/hooks/" \
    || handson::die "non riesco a copiare gli hook"
  handson::git_init_workspace "${COPIA}" "${ELEMENTO}" \
    || handson::die "git non riesce a fare il repository di ${COPIA}"
}
