# shellcheck shell=bash
# =====================================================================
# lib_turni_m4.sh -- un turno di claude -p delle prove dal vivo del
# laboratorio del Modulo 4 (i _docente/live.sh di M4-E01…E05), con tutti i
# suoi risultati: la chiamata in stream-json, lo stream intero in
# <base>.jsonl, il suo ultimo risultato in <base>.json e il riepilogo che
# somma i turni del modello, la durata e i token di ogni risultato.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun
# bit di esecuzione). La caricano lib_live_m4_e01_e02.sh,
# lib_live_m4_e04_e05.sh e il _docente/live.sh di M4-E03.
#
# Perché lo stream: quando un subagent lavora in background, la
# conversazione principale risponde prima, e la notifica del subagent
# apre un altro segmento della stessa chiamata, con il suo risultato. Il
# JSON di --output-format json descrive solo l'ultimo segmento; lo
# stream-json (con --verbose) li ha tutti, ognuno con il suo evento
# «result». Il riepilogo li somma; <base>.json è l'ultimo di quei
# risultati: l'ID di sessione e la risposta vi stanno come nel JSON di
# --output-format json, così chi lo legge non cambia.
# La durata è la somma delle durate dei risultati: il tempo in cui la
# conversazione principale lavora, senza le attese fra un segmento e
# l'altro.
# =====================================================================

# Una seconda `source` nello stesso processo non ridefinisce niente.
if [[ -n "${TURNI_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly TURNI_LIB_LOADED=1

# Il riepilogo di un turno dai risultati del suo stream (filtro di jq, su
# tutto lo stream letto con -s): con più di un risultato, quanti segmenti.
# shellcheck disable=SC2016  # \(…), $r, $k e $n sono di jq, in tutto il blocco
{
  TURNI_RIEPILOGO='map(select(type == "object" and .type == "result")) as $r'
  TURNI_RIEPILOGO+=' | ($r | length) as $k'
  TURNI_RIEPILOGO+=' | "  turno \($n): \($r | map(.num_turns // 0)'
  TURNI_RIEPILOGO+=' | add // 0) turni del modello"'
  TURNI_RIEPILOGO+=' + (if $k > 1 then " in \($k) segmenti" else "" end)'
  TURNI_RIEPILOGO+=' + ", \((($r | map(.duration_ms // 0) | add // 0)'
  TURNI_RIEPILOGO+=' / 1000) | floor) s, token in entrata \($r | map('
  TURNI_RIEPILOGO+='(.usage.input_tokens // 0)'
  TURNI_RIEPILOGO+=' + (.usage.cache_creation_input_tokens // 0)'
  TURNI_RIEPILOGO+=' + (.usage.cache_read_input_tokens // 0)) | add // 0),'
  TURNI_RIEPILOGO+=' in uscita \($r | map(.usage.output_tokens // 0)'
  TURNI_RIEPILOGO+=' | add // 0)"'
}
readonly TURNI_RIEPILOGO

# Un turno: claude -p in stream-json (handson::claude_p con
# HANDSON_OUTPUT_FORMAT=stream-json, che aggiunge --verbose), lo stream in
# <base>.jsonl, il suo ultimo risultato in <base>.json. Va chiamata nella
# shell dello script, non dentro $(…): così una precondizione di
# handson::claude_p esce davvero con 2.
# Arguments: $1 la base dei due file (senza estensione), $2 il modello, $3
#   gli strumenti consentiti, $4 il testo, poi le opzioni in più (per
#   esempio --resume <ID>).
# Outputs: su STDERR, perché un turno non è riuscito.
# Returns: 0; 1 se claude fallisce, se lo stream ha una riga che non è JSON
#   o se non ha un risultato.
turni::chiama() {
  local base="$1" modello="$2" strumenti="$3" testo="$4" rc=0
  shift 4
  # shellcheck disable=SC2034  # la legge handson::claude_p
  local HANDSON_OUTPUT_FORMAT=stream-json
  handson::claude_p "${modello}" "${strumenti}" "${testo}" "$@" \
    > "${base}.jsonl" || rc=$?
  if (( rc != 0 )); then
    handson::err "turni: claude -p è uscito con ${rc} (${base}.jsonl)"
    return 1
  fi
  if ! jq -cs 'map(select(type == "object" and .type == "result")) | last
      | select(. != null)' "${base}.jsonl" > "${base}.json" 2> /dev/null
  then
    handson::err "turni: ${base}.jsonl ha una riga che non è JSON"
    return 1
  fi
  if [[ ! -s "${base}.json" ]]; then
    handson::err "turni: ${base}.jsonl non ha un risultato"
    return 1
  fi
}

# Il riepilogo di un turno, dal suo stream: i turni del modello, la durata
# e i token di tutti i suoi risultati, sommati.
# Arguments: $1 il numero del turno, $2 lo stream.
# Outputs: la riga su STDOUT, o che lo stream non si legge.
turni::riepilogo() {
  jq -rs --arg n "$1" "${TURNI_RIEPILOGO}" "$2" 2> /dev/null \
    || printf '  turno %s: lo stream non si legge\n' "$1"
}
