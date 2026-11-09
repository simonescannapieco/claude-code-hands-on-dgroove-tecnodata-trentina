#!/bin/bash
#
# tests/test_assistenza_banco.sh -- le prove del banco di prova
# dell'assistente (progetti/assistenza-clienti/banco/) e del suo punto di
# ingresso (tools/prova_assistente.sh), con un claude finto: nessuna chiamata
# a un modello, nessuna rete. Il server MCP vero gira nelle prove dal vivo.
#
# Coperture: le capacità del motore sui dati di uno scenario, i nomi del v0,
# gli errori; le definizioni degli strumenti che non si possono usare; le
# asserzioni di un caso; la lettura di uno stream; prova.py sui casi, su una
# conversazione e sul giudice; il confronto fra due versioni; i casi forniti.
#
# Uso: tests/test_assistenza_banco.sh
# Uscita: 0 nessun test fallito · 1 almeno un test fallito · 2 prerequisito
# mancante.
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ROOT="${SELF%/tests/*}"
readonly PROJ="${ROOT}/progetti/assistenza-clienti"
readonly BANCO="${PROJ}/banco"
TMP="$(mktemp -d)"
readonly TMP
trap 'rm -rf "${TMP}"' EXIT
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if ! command -v python3 > /dev/null 2>&1; then
  echo "FATALE: manca python3" >&2
  exit 2
fi

# Il claude finto: una sola riga del registro, uno stream, una persona che
# chiude al primo giro, un giudice che dà 2 a tutti i criteri.
mkdir -p "${TMP}/bin"
cat > "${TMP}/fake_claude.py" <<'FINTO'
import json
import os
import sys

argv = sys.argv[1:]
modo = os.environ.get("FAKE_MODE", "ok")
if modo == "rc1":
    sys.stderr.write("errore finto\n")
    sys.exit(1)


def valore(flag):
    return argv[argv.index(flag) + 1] if flag in argv else None


with open(os.environ["FAKE_ARGS"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(argv, ensure_ascii=False) + "\n")
if os.environ.get("FAKE_ENV"):
    with open(os.environ["FAKE_ENV"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps({k: os.environ.get(k) for k in (
            "HTTPS_PROXY", "HTTP_PROXY", "NO_PROXY", "https_proxy",
            "http_proxy", "no_proxy", "NODE_EXTRA_CA_CERTS", "SSL_CERT_FILE",
            "CLAUDE_CONFIG_DIR", "ANTHROPIC_API_KEY")}) + "\n")
if modo == "sessione" and os.environ.get("CLAUDE_CONFIG_DIR"):
    # Una sessione salvata per la cartella di lavoro, come fa Claude Code.
    mangle = "".join(c if c.isalnum() else "-" for c in os.getcwd())
    cartella = os.path.join(os.environ["CLAUDE_CONFIG_DIR"], "projects", mangle)
    os.makedirs(cartella, exist_ok=True)
    open(os.path.join(cartella, "s.jsonl"), "w", encoding="utf-8").close()

if "--agent" in argv and "--json-schema" not in argv:
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "result": "FINE", "num_turns": 1,
                      "duration_ms": 10, "session_id": "s-persona"}))
    sys.exit(0)
if "--json-schema" in argv and "--agent" in argv:
    punti = {"C%d" % i: 2 for i in range(1, 10)}
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "result": "fatto", "num_turns": 1,
                      "duration_ms": 10, "session_id": "s-giudice",
                      "structured_output": {
                          "punteggi": punti,
                          "motivazioni": {"C1": "ok"}}}))
    sys.exit(0)

config = json.load(open(valore("--mcp-config"), encoding="utf-8"))
env = config["mcpServers"]["assistenza"]["env"]
if modo == "registro_rotto":
    with open(env["BANCO_REGISTRO"], "a", encoding="utf-8") as fh:
        fh.write("questa riga non è JSON\n")
if modo not in ("muto", "server_ko", "server_auth", "senza_strumenti",
                "registro_rotto"):
    with open(env["BANCO_REGISTRO"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps({"n": 1, "strumento": "stato_linea",
                             "capacita": "stato_linea",
                             "argomenti": {"id_linea": "LN-000201"},
                             "risultato": {"stato": "guasto"},
                             "errore": False}) + "\n")
stato = {"server_ko": "failed", "server_auth": "needs-auth"}.get(modo,
                                                                 "connected")
strumenti = ["mcp__assistenza__stato_linea"]
if modo in ("server_ko", "server_auth", "senza_strumenti"):
    strumenti = []
if modo != "senza_init":
    print(json.dumps({"type": "system", "subtype": "init", "session_id": "s-1",
                      "tools": strumenti,
                      "mcp_servers": [{"name": "assistenza", "status": stato}]}))
print(json.dumps({"type": "assistant", "parent_tool_use_id": None, "message": {
    "usage": {"input_tokens": 10, "cache_creation_input_tokens": 90,
              "cache_read_input_tokens": 0, "output_tokens": 5},
    "content": [{"type": "tool_use", "id": "t1",
                 "name": "mcp__assistenza__stato_linea",
                 "input": {"id_linea": "LN-000201"}}]}}))
if modo != "senza_esito":
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "num_turns": 2, "duration_ms": 1500,
                      "result": "Risposta finta: guasto a Pergine.",
                      "session_id": "s-1",
                      "structured_output": {"coperta": True}
                      if "--json-schema" in argv else None,
                      "usage": {"input_tokens": 10, "output_tokens": 5}}))
FINTO
# prova.py ripulisce l'ambiente: il claude finto sa il modo e dove scrivere gli
# argomenti da due file, non dalle variabili di chi lo lancia.
cat > "${TMP}/bin/claude" <<FINTO
#!/bin/bash
export FAKE_ARGS="${TMP}/args.log"
export FAKE_ENV="${TMP}/env.log"
FAKE_MODE="\$(cat "${TMP}/fake_mode" 2>/dev/null || echo ok)"
export FAKE_MODE
exec python3 -B -I "${TMP}/fake_claude.py" "\$@"
FINTO
chmod +x "${TMP}/bin/claude"
: > "${TMP}/args.log"
# uv finto: prova.py lo lancia una volta per preparare l'ambiente del server.
cat > "${TMP}/bin/uv" <<FINTO
#!/bin/bash
[[ ! -f "${TMP}/uv_rotto" ]] || { echo "uv rotto" >&2; exit 1; }
printf '%s %s\n' "\${HTTPS_PROXY:-}" "\${ANTHROPIC_API_KEY:-no}" \
  > "${TMP}/uv_env.log"
exit 0
FINTO
chmod +x "${TMP}/bin/uv"

# Sceglie come si comporta il claude finto. Arguments: $1 il modo.
modo() { printf '%s' "$1" > "${TMP}/fake_mode"; }
modo ok

# Esegue uno snippet Python con il banco importabile.
# Arguments: lo snippet su stdin. Outputs: ciò che stampa.
py() { python3 -B -I -c "import sys; sys.path.insert(0, '${BANCO}'); exec(sys.stdin.read())"; }

test_motore() {
  local out rc
  out="$(py 2>&1 <<EOF
import json, pathlib
import motore
sc = json.load(open("${PROJ}/scenari/sc-01-fibra-assente-guasto-pergine.json"))
b = motore.Banco(sc, pathlib.Path("${PROJ}/kb"))
def c(n, a): return b.esegui(n, a)
r, e, k = c("verifica_identita", {"codice": "CL-000101", "recapito": "laura.prova@example.org"})
assert (r["esito"], e, r["linee"]) == ("riconosciuto", False, ["LN-000201"]), r
r, e, k = c("verifica_identita", {"codice": "CL-000101", "recapito": "altro@example.org"})
assert r == {"esito": "non riconosciuto"} and not e, r
r, e, k = c("stato_linea", {"linea": "LN-000201"})
assert r["guasto_collettivo"]["zona"] == "Pergine Valsugana" and not e, r
assert "note" not in r
r, e, k = c("stato_linea", {"linea": "LN-999999"})
assert e and "errore" in r, r
r, e, k = c("guasti_in_corso", {"comune": "Pergine"})
assert len(r["guasti"]) == 1, r
r, e, k = c("guasti_in_corso", {"comune": "Bolzano"})
assert r["guasti"] == [], r
r, e, k = c("cerca_kb", {"domanda": "guasto collettivo manutenzione programmata"})
assert r["risultati"] and r["risultati"][0]["id"].startswith("KB-"), r
assert set(r["risultati"][0]) == {"id", "titolo", "estratto"}, r
r, e, k = c("cerca_kb", {"domanda": "zzzzqqq"})
assert r == {"risultati": []}, r
r, e, k = c("gestisci_ticket", {"azione": "apri", "dati": "linea guasta"})
assert k == "apri_ticket" and r["id_ticket"].startswith("TK-2026-"), (r, k)
r, e, k = c("registra_accredito", {"importo": 10})
assert r["registrato"] is True, r
r, e, k = c("passa_a_operatore", {"motivo": "x"})
assert r["esito"] == "presa in carico", r
r, e, k = c("capacita_che_non_esiste", {})
assert e and "errore" in r, r
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "motore: le capacità sui dati dello scenario e gli errori"
  else
    fail "motore: rc=${rc}: ${out}"
  fi
}

test_scheda_e_copertura() {
  local out rc
  out="$(py 2>&1 <<EOF
import json, pathlib
import motore
sc = json.load(open("${PROJ}/scenari/sc-08-copertura-fibra-in-arrivo.json")) if False else None
import glob
sc = json.load(open(glob.glob("${PROJ}/scenari/sc-08-*.json")[0]))
b = motore.Banco(sc, pathlib.Path("${PROJ}/kb"))
r, e, k = b.esegui("verifica_copertura", {"via": "Via della Fantasia 103", "comune": "Levico Terme"})
assert "in arrivo" in r["fibra"] and not e, r
r, e, k = b.esegui("verifica_copertura", {"via": "Via della Fantasia", "comune": "Levico Terme"})
assert e and "civico" in r["errore"], r
sc = json.load(open(glob.glob("${PROJ}/scenari/sc-10-*.json")[0]))
b = motore.Banco(sc, pathlib.Path("${PROJ}/kb"))
r, e, k = b.esegui("leggi_fattura", {"numero": "FT-2026-001873"})
assert r["id_fattura"] == "FT-2026-001873" and not e, r
r, e, k = b.esegui("leggi_fattura", {"numero": "FT-2026-000001"})
assert e, r
r, e, k = b.esegui("cerca_cliente", {"q": "Paolo Simulato"})
assert r["cliente"]["id_cliente"] == "CL-005002" and "credenziali" in r, r
r, e, k = b.esegui("cerca_cliente", {"q": "Nessuno"})
assert r == {"risultati": []}, r
sc = json.load(open(glob.glob("${PROJ}/scenari/sc-07-*.json")[0]))
b = motore.Banco(sc, pathlib.Path("${PROJ}/kb"))
r, e, k = b.esegui("slot_disponibili", {})
assert r["fasce"], r
quando = r["fasce"][0]["inizio"]
r, e, k = b.esegui("prenota_intervento", {"quando": "domani"})
assert e and "fascia" in r["errore"], r
r, e, k = b.esegui("prenota_intervento", {"quando": quando})
assert r["esito"] == "prenotato" and r["id_appuntamento"].startswith("AT-2026-"), r
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "motore: copertura, fatture, scheda e appuntamenti"
  else
    fail "scheda e copertura: rc=${rc}: ${out}"
  fi
}

test_definizioni() {
  local out rc
  out="$(py 2>&1 <<EOF
import json, pathlib, tempfile
import motore
v0 = motore.carica_strumenti(pathlib.Path("${PROJ}/v0/strumenti.json"))
assert len(v0) == 10, len(v0)
nomi = {d.nome: d.capacita for d in v0}
assert nomi["check_linea"] == "stato_linea" and nomi["accredito"] == "registra_accredito", nomi
assert nomi["ticket"] == "gestisci_ticket", nomi
def prova(lista):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        json.dump(lista, fh)
    try:
        return motore.carica_strumenti(pathlib.Path(fh.name))
    except motore.Problema as exc:
        return str(exc)
buona = {"name": "controlla_linea", "description": "x", "input_schema": {"type": "object", "properties": {}}, "capacita": "stato_linea"}
r = prova([buona])
assert r[0].capacita == "stato_linea", r
assert "capacita" not in r[0].schema, r[0].schema
assert "non collegato" in prova([dict(buona, capacita="boh")]), prova([dict(buona, capacita="boh")])
senza = {k: v for k, v in buona.items() if k != "capacita"}
assert "non collegato" in prova([senza]), prova([senza])
assert "input_schema" in prova([{"name": "a", "description": "x", "capacita": "stato_linea"}])
assert "doppio" in prova([buona, buona]), prova([buona, buona])
assert "name" in prova([dict(buona, name="con spazi")])
assert "lista" in prova({"a": 1})
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "definizioni degli strumenti: i nomi del v0, capacita, gli errori"
  else
    fail "definizioni: rc=${rc}: ${out}"
  fi
}

test_asserzioni() {
  local out rc
  out="$(py 2>&1 <<EOF
import lib_banco as L
chiamate = [{"capacita": "verifica_identita"}, {"capacita": "stato_linea"}, {"capacita": "apri_ticket"}]
caso = {"asserzioni": {
  "deve_chiamare": ["stato_linea", "leggi_fattura"],
  "non_deve_chiamare": ["registra_accredito", "apri_ticket"],
  "prima_di": [["verifica_identita", "stato_linea"], ["stato_linea", "verifica_identita"], ["leggi_fattura", "prenota_intervento"]],
  "risposta_contiene": ["guasto"],
  "risposta_non_contiene": ["24 ore", "pergine"],
  "escalation": False}}
e = L.valuta(caso, chiamate, "C'è un guasto a Pergine")
d = {(x["tipo"], x["oggetto"]): x["esito"] for x in e}
assert d[("deve_chiamare", "stato_linea")] is True
assert d[("deve_chiamare", "leggi_fattura")] is False
assert d[("non_deve_chiamare", "registra_accredito")] is True
assert d[("non_deve_chiamare", "apri_ticket")] is False
assert d[("prima_di", "verifica_identita < stato_linea")] is True
assert d[("prima_di", "stato_linea < verifica_identita")] is False
assert d[("prima_di", "leggi_fattura < prenota_intervento")] is True
assert d[("risposta_contiene", "guasto")] is True
assert d[("risposta_non_contiene", "24 ore")] is True
assert d[("risposta_non_contiene", "pergine")] is False
assert d[("escalation", "no")] is True
e = L.valuta({"asserzioni": {"escalation": True}}, chiamate, "x")
assert e[0]["esito"] is False and e[0]["oggetto"] == "sì", e
e = L.valuta({"asserzioni": {"escalation": True}}, chiamate + [{"capacita": "passa_a_operatore"}], "x")
assert e[0]["esito"] is True, e
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "asserzioni: ogni tipo, vero e falso; prima_di con il secondo assente"
  else
    fail "asserzioni: rc=${rc}: ${out}"
  fi
}

test_stream() {
  local out rc
  out="$(py 2>&1 <<'EOF'
import json
import lib_banco as L
init = json.dumps({"type": "system", "subtype": "init", "session_id": "s-9", "tools": ["mcp__assistenza__x"], "mcp_servers": [{"name": "assistenza", "status": "connected"}]})
righe = [
  init,
  json.dumps({"type": "assistant", "parent_tool_use_id": None, "message": {"usage": {"input_tokens": 1, "cache_creation_input_tokens": 2, "cache_read_input_tokens": 3}, "content": [{"type": "tool_use", "name": "mcp__assistenza__x", "input": {}}]}}),
  json.dumps({"type": "assistant", "parent_tool_use_id": None, "message": {"usage": {"input_tokens": 50}, "content": [{"type": "text", "text": "ciao"}]}}),
  json.dumps({"type": "result", "is_error": False, "num_turns": 3, "duration_ms": 2000, "result": "ciao", "session_id": "s-9"}),
]
s = L.leggi_stream("\n".join(righe))
assert s["completa"] and not s["errore"] and s["problema"] is None, s
assert s["risposta"] == "ciao" and s["turni"] == 3 and s["sessione"] == "s-9", s
assert s["token_prima_richiesta"] == 6 and s["strumenti"] == ["x"], s
assert s["secondi"] == 2.0, s
s = L.leggi_stream(righe[0])
assert not s["completa"], s
s = L.leggi_stream(init + '\n{"type": "result", "is_error": true, "num_turns": 1, "duration_ms": 1, "result": "boom"}')
assert s["errore"] and s["completa"], s
s = L.leggi_stream("non è json")
assert not s["completa"], s
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "stream: risposta, turni, token della prima richiesta, stream rotti"
  else
    fail "stream: rc=${rc}: ${out}"
  fi
}

# Il server MCP del banco visto dall'evento init: failed e needs-auth non sono
# esecuzioni; nemmeno un init senza gli strumenti del server; pending, da solo,
# non è un guasto.
test_stream_server() {
  local out rc
  out="$(py 2>&1 <<'EOF'
import json
import lib_banco as L
fine = json.dumps({"type": "result", "is_error": False, "num_turns": 1, "duration_ms": 1, "result": "ciao"})
def stream(stato, strumenti):
    init = {"type": "system", "subtype": "init", "tools": strumenti}
    if stato is not None:
        init["mcp_servers"] = [{"name": "altro", "status": "failed"}, {"name": "assistenza", "status": stato}]
    return L.leggi_stream(json.dumps(init) + "\n" + fine)
giusti = ["mcp__assistenza__x", "StructuredOutput"]
for stato in ("connected",):
    s = stream(stato, giusti)
    assert s["completa"] and s["problema"] is None, s
for stato in ("failed", "needs-auth"):
    s = stream(stato, giusti)
    assert not s["completa"] and stato in s["problema"] and "non è finita" not in s["problema"], s
    s = stream(stato, [])
    assert not s["completa"] and stato in s["problema"], s
s = stream("connected", ["StructuredOutput"])
assert not s["completa"] and "assistenza" in s["problema"], s
s = stream(None, giusti)
assert s["completa"] and s["problema"] is None, s
s = stream(None, [])
assert not s["completa"], s
s = stream("pending", [])
assert s["completa"] and s["problema"] is None, s
s = stream("pending", giusti)
assert s["completa"] and s["problema"] is None, s
s = L.leggi_stream(fine)
assert not s["completa"] and "init" in s["problema"], s
# Un init compattato, senza «tools» né «mcp_servers» (le copie in soluzione/ della
# registrazione): non dice nulla del server, e non è un guasto.
s = L.leggi_stream(json.dumps({"type": "system", "subtype": "init", "model": "m"}) + "\n" + fine)
assert s["completa"] and s["problema"] is None, s
s = L.leggi_stream(json.dumps({"type": "system", "subtype": "init", "tools": 7, "mcp_servers": "x"}) + "\n" + fine)
assert not s["completa"], s
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "stream: un server failed, needs-auth o senza strumenti non è un'esecuzione; pending da solo sì"
  else
    fail "stream del server: rc=${rc}: ${out}"
  fi
  out="$(py 2>&1 <<EOF
import pathlib
import lib_banco as L
p = pathlib.Path("${TMP}/registro_prova.jsonl")
p.write_text('{"n": 1, "capacita": "x"}\n\n{"n": 2, "capacita": "y"}\n', encoding="utf-8")
assert [c["n"] for c in L.leggi_registro(p)] == [1, 2]
for riga in ("non è json", "[1, 2]", "{rotta"):
    p.write_text('{"n": 1}\n' + riga + "\n", encoding="utf-8")
    try:
        L.leggi_registro(p)
    except L.Problema as exc:
        assert "riga 2" in str(exc), exc
    else:
        raise SystemExit("nessun Problema su: " + riga)
assert L.leggi_registro(pathlib.Path("${TMP}/non-c-e.jsonl")) == []
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "registro: una riga del server che non è JSON è un Problema; righe vuote e file assente no"
  else
    fail "registro: rc=${rc}: ${out}"
  fi
}

# Scrive due casi di prova. Arguments: $1 la cartella.
scrivi_casi() {
  mkdir -p "$1"
  cat > "$1/a.json" <<'EOF'
{"id": "CASO-A", "titolo": "uno", "scenario": "sc-01-fibra-assente-guasto-pergine.json",
 "messaggio": "Buongiorno",
 "asserzioni": {"deve_chiamare": ["stato_linea"], "risposta_contiene": ["guasto"]}}
EOF
  cat > "$1/b.json" <<'EOF'
{"id": "CASO-B", "titolo": "due", "scenario": "sc-01-fibra-assente-guasto-pergine.json",
 "messaggio": "Salve",
 "asserzioni": {"deve_chiamare": ["leggi_fattura"]}}
EOF
}

# Esegue prova.py con il claude finto. Arguments: gli argomenti di prova.py.
# Outputs: STDOUT e STDERR di prova.py. Returns: la sua uscita.
prova() {
  env PATH="${TMP}/bin:${PATH}" \
    python3 -B -I "${BANCO}/prova.py" "$@" 2>&1
}

test_casi_ok() {
  local casi="${TMP}/casi1" u="${TMP}/u1" out rc
  scrivi_casi "${casi}"
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${u}")"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == *"CASO-A"*"2/2"* ]] \
    && [[ "${out}" == *"CASO-B"*"0/1"* ]] \
    && [[ -f "${u}/CASO-A/esito.json" && -f "${u}/CASO-A/registro.jsonl" ]] \
    && [[ -f "${u}/CASO-A/trascrizione.md" && -f "${u}/CASO-A/stream.jsonl" ]]
  then
    pass "casi: due casi, gli esiti scritti, l'esito delle asserzioni è un dato (rc 0)"
  else
    fail "casi ok: rc=${rc}: ${out}"
  fi
  if command grep -q -- '"--system-prompt-file"' "${TMP}/args.log" \
    && command grep -q -- '"--strict-mcp-config"' "${TMP}/args.log" \
    && command grep -q -- '"mcp__assistenza__\*"' "${TMP}/args.log" \
    && command grep -q -- '"--no-session-persistence"' "${TMP}/args.log" \
    && ! command grep -q -- 'bypassPermissions' "${TMP}/args.log"; then
    pass "casi: la riga di claude ha le opzioni del banco e nessun bypass"
  else
    fail "casi: la riga di claude: $(head -1 "${TMP}/args.log")"
  fi
  local sp
  sp="$(python3 -B -I -c 'import json,sys
a=json.loads(open(sys.argv[1]).readline()); print(a[a.index("--tools")+1]=="" )' "${TMP}/args.log")"
  if [[ "${sp}" == "True" ]]; then
    pass "casi: --tools vuoto, niente strumenti integrati"
  else
    fail "casi: --tools: ${sp}"
  fi
  if python3 -B -I -c 'import json,sys
e=json.load(open(sys.argv[1])); assert e["versione"]=="v0" and e["soddisfatte"]==2 and e["totale"]==2 and e["completa"] and e["token_prima_richiesta"]==100 and e["chiamate"][0]["capacita"]=="stato_linea"' "${u}/CASO-A/esito.json" 2>/dev/null; then
    pass "casi: esito.json con versione, conteggi, token, chiamate"
  else
    fail "casi: esito.json: $(cat "${u}/CASO-A/esito.json")"
  fi
}

test_casi_rotti() {
  local casi="${TMP}/casi2" out rc
  scrivi_casi "${casi}"
  modo rc1
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u2")"
  rc=$?
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]]; then
    pass "casi: una chiamata che fallisce dà uscita 1"
  else
    fail "casi rc1: rc=${rc}: ${out}"
  fi
  modo senza_esito
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u3")"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]]; then
    pass "casi: uno stream senza risultato dà uscita 1"
  else
    fail "casi senza esito: rc=${rc}: ${out}"
  fi
  out="$(prova casi --versione "${TMP}/non-c-e" --casi "${casi}" --uscita "${TMP}/u4")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"system-prompt.md"* ]]; then
    pass "casi: una versione che manca è una precondizione (rc 2)"
  else
    fail "casi versione: rc=${rc}: ${out}"
  fi
  mkdir -p "${TMP}/casi3"
  printf '{"id": "X"}\n' > "${TMP}/casi3/x.json"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${TMP}/casi3" --uscita "${TMP}/u5")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"scenario"* ]]; then
    pass "casi: un caso senza i campi è una precondizione (rc 2)"
  else
    fail "casi malformati: rc=${rc}: ${out}"
  fi
  mkdir -p "${TMP}/u6/CASO-A"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u6")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"${TMP}/u6 esiste già: cancellatela e rilanciate con lo stesso nome"* ]] \
    && [[ "${out}" == *"un'altra uscita solo per una prova in più"* ]] \
    && [[ "${out}" != *"scegliete"* ]]; then
    pass "casi: non sovrascrive una prova già fatta (rc 2) e dice di cancellarla e rilanciare"
  else
    fail "casi sovrascrittura: rc=${rc}: ${out}"
  fi
}

# La versione si controlla prima di ogni chiamata: una capacita sbagliata, una
# definizione rotta, una base di conoscenza che non è una cartella.
test_versione_prima_di_tutto() {
  local casi="${TMP}/casi20" v="${TMP}/v20" out rc
  scrivi_casi "${casi}"
  mkdir -p "${v}"
  printf 'Sei un assistente.\n' > "${v}/system-prompt.md"
  python3 -B -I - "${PROJ}/v0/strumenti.json" "${v}/strumenti.json" <<'PY'
import json, sys
dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati[0]["capacita"] = "capacita_che_non_esiste"
json.dump(dati, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${v}" --casi "${casi}" --uscita "${TMP}/u20")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"strumento non collegato"* ]] \
    && [[ "${out}" == *"capacita"* ]] \
    && (( $(wc -l <<< "${out}") == 1 )) \
    && [[ ! -s "${TMP}/args.log" ]] && [[ ! -e "${TMP}/u20" ]]; then
    pass "casi: una capacita sbagliata è una precondizione (rc 2), in una riga, nessuna chiamata"
  else
    fail "casi capacita: rc=${rc}, args $(wc -c < "${TMP}/args.log"): ${out}"
  fi
  printf '{rotto\n' > "${v}/strumenti.json"
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${v}" --casi "${casi}" --uscita "${TMP}/u21")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"strumenti.json"* ]] \
    && [[ ! -s "${TMP}/args.log" ]]; then
    pass "casi: uno strumenti.json che non si legge è una precondizione (rc 2), nessuna chiamata"
  else
    fail "casi strumenti rotti: rc=${rc}: ${out}"
  fi
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --kb "${TMP}/kb-che-non-c-e" --uscita "${TMP}/u22")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"--kb"* ]] \
    && [[ ! -s "${TMP}/args.log" ]]; then
    pass "casi: --kb che non è una cartella è una precondizione (rc 2), nessuna chiamata"
  else
    fail "casi kb: rc=${rc}: ${out}"
  fi
}

# Un caso malformato: uscita 2, un messaggio, nessun traceback, nessuna
# chiamata. Arguments: $1 il nome, $2 la parola attesa, $3 il JSON del caso.
un_caso_malformato() {
  local casi="${TMP}/casi_m" out rc
  rm -rf "${casi}"
  scrivi_casi "${casi}"
  printf '%s\n' "$3" > "${casi}/z.json"
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u_m")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"$2"* ]] && [[ "${out}" != *Traceback* ]] \
    && [[ ! -s "${TMP}/args.log" ]] && [[ ! -e "${TMP}/u_m" ]]; then
    pass "casi malformati: $1 (rc 2, prima di ogni chiamata)"
  else
    fail "caso malformato, $1: rc=${rc}: ${out}"
  fi
}

test_casi_malformati() {
  local s='"scenario": "sc-01-fibra-assente-guasto-pergine.json", "messaggio": "m"'
  un_caso_malformato "un'espressione regolare rotta" "espressione regolare" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"risposta_contiene\": [\"(rotta\"]}}"
  un_caso_malformato "una regex rotta in risposta_non_contiene" "espressione regolare" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"risposta_non_contiene\": [\"[z\"]}}"
  un_caso_malformato "prima_di senza coppie" "prima_di" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"prima_di\": [\"a\", \"b\"]}}"
  un_caso_malformato "prima_di con tre nomi" "prima_di" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"prima_di\": [[\"a\", \"b\", \"c\"]]}}"
  un_caso_malformato "prima_di che non è una lista" "prima_di" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"prima_di\": \"a\"}}"
  un_caso_malformato "asserzioni che non è un oggetto" "asserzioni" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": [\"deve_chiamare\"]}"
  un_caso_malformato "deve_chiamare che non è una lista" "deve_chiamare" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"deve_chiamare\": \"stato_linea\"}}"
  un_caso_malformato "un elemento che non è un testo" "non_deve_chiamare" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"non_deve_chiamare\": [1]}}"
  un_caso_malformato "escalation che non è vero o falso" "escalation" \
    "{\"id\": \"Z\", ${s}, \"asserzioni\": {\"escalation\": \"sì\"}}"
  un_caso_malformato "un id che non è un testo" "id" \
    "{\"id\": 7, ${s}, \"asserzioni\": {}}"
  un_caso_malformato "un id che è un percorso" "id" \
    "{\"id\": \"../fuori\", ${s}, \"asserzioni\": {}}"
  un_caso_malformato "un messaggio vuoto" "messaggio" \
    '{"id": "Z", "scenario": "sc-01-fibra-assente-guasto-pergine.json", "messaggio": " ", "asserzioni": {}}'
  un_caso_malformato "uno scenario che non è un testo" "scenario" \
    '{"id": "Z", "scenario": 5, "messaggio": "m", "asserzioni": {}}'
  printf '[1]\n' > "${TMP}/scenario_lista.json"
  un_caso_malformato "uno scenario che non è un oggetto" "non è un oggetto" \
    "{\"id\": \"Z\", \"scenario\": \"${TMP}/scenario_lista.json\", \"messaggio\": \"m\", \"asserzioni\": {}}"
  un_caso_malformato "un file che non è un oggetto" "manca il campo" \
    '[1, 2, 3]'
}

test_id_doppi() {
  local casi="${TMP}/casi_d" out rc
  scrivi_casi "${casi}"
  cp "${casi}/a.json" "${casi}/c.json"
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u_d")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"CASO-A"* ]] && [[ "${out}" == *"stesso id"* ]] \
    && [[ "${out}" != *Traceback* ]] && [[ ! -s "${TMP}/args.log" ]]; then
    pass "casi: due file con lo stesso id sono una precondizione (rc 2), nessuna chiamata"
  else
    fail "id doppi: rc=${rc}: ${out}"
  fi
}

# Il server che non parte non è una prova fatta: «non è finita», uscita 1, e
# il confronto non la conta.
test_server_che_non_parte() {
  local casi="${TMP}/casi30" u="${TMP}/u30" a="${TMP}/u30ok" out rc
  scrivi_casi "${casi}"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${a}")"
  rc=$?
  (( rc == 0 )) || fail "server: la prova di partenza: rc=${rc}: ${out}"
  modo server_ko
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${u}")"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"CASO-A"*"non è finita"* ]] \
    && [[ "${out}" == *"failed"* ]] \
    && python3 -B -I -c 'import json,sys
e=json.load(open(sys.argv[1],encoding="utf-8")); assert e["completa"] is False and "failed" in e["problema"] and e["chiamate"]==[]' "${u}/CASO-A/esito.json" 2>/dev/null; then
    pass "casi: un server failed non è un'esecuzione (rc 1, «non è finita», il motivo)"
  else
    fail "casi server failed: rc=${rc}: ${out}"
  fi
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${u}" 2>&1)"
  rc=$?
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]]; then
    pass "confronta: una prova con il server failed non si confronta (rc 1)"
  else
    fail "confronta server failed: rc=${rc}: ${out}"
  fi
  modo server_auth
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u31")"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]] \
    && [[ "${out}" == *"needs-auth"* ]]; then
    pass "casi: un server needs-auth non è un'esecuzione (rc 1)"
  else
    fail "casi server needs-auth: rc=${rc}: ${out}"
  fi
  modo senza_strumenti
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u32")"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]] \
    && [[ "${out}" == *"strumenti"* ]]; then
    pass "casi: nessuno strumento del server nell'elenco non è un'esecuzione (rc 1)"
  else
    fail "casi senza strumenti: rc=${rc}: ${out}"
  fi
  modo senza_init
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u33")"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]]; then
    pass "casi: uno stream senza l'evento init non è un'esecuzione (rc 1)"
  else
    fail "casi senza init: rc=${rc}: ${out}"
  fi
  local sc
  sc="$(printf '%s' "${PROJ}"/scenari/sc-01-*.json)"
  modo server_ko
  out="$(prova conversazione --versione "${PROJ}/v0" --scenario "${sc}" --uscita "${TMP}/c30" --giri 2)"
  rc=$?
  modo ok
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]] \
    && [[ "${out}" == *"failed"* ]] && [[ "${out}" == *"0 giri"* ]]; then
    pass "conversazione: un server failed ferma la conversazione (rc 1, il motivo, 0 giri)"
  else
    fail "conversazione server failed: rc=${rc}: ${out}"
  fi
}

test_registro_rotto() {
  local casi="${TMP}/casi40" out rc
  scrivi_casi "${casi}"
  modo registro_rotto
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u40")"
  rc=$?
  modo ok
  if (( rc == 2 )) && [[ "${out}" == *"registro"* ]] \
    && [[ "${out}" != *Traceback* ]]; then
    pass "casi: una riga del registro del server che non è JSON è una precondizione (rc 2)"
  else
    fail "registro rotto: rc=${rc}: ${out}"
  fi
}

test_scenario_e_conversazioni_malformati() {
  local gc out rc
  gc="$(printf '%s' "${PROJ}"/golden/gc-01-*.json)"
  : > "${TMP}/args.log"
  out="$(prova conversazione --versione "${PROJ}/v0" --scenario "${gc}" --uscita "${TMP}/c40")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"messaggio_iniziale"* ]] \
    && [[ "${out}" != *Traceback* ]] && [[ ! -s "${TMP}/args.log" ]] \
    && [[ ! -e "${TMP}/c40" ]]; then
    pass "conversazione: --scenario su un file senza messaggio_iniziale è una precondizione (rc 2)"
  else
    fail "scenario malformato: rc=${rc}: ${out}"
  fi
  printf '[1]\n' > "${TMP}/non_oggetto.json"
  : > "${TMP}/args.log"
  out="$(prova conversazione --versione "${PROJ}/v0" --scenario "${TMP}/non_oggetto.json" --uscita "${TMP}/c41")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"non è un oggetto"* ]] \
    && [[ "${out}" != *Traceback* ]] && [[ ! -s "${TMP}/args.log" ]]; then
    pass "conversazione: uno scenario che non è un oggetto è una precondizione (rc 2)"
  else
    fail "scenario non oggetto: rc=${rc}: ${out}"
  fi
  printf '{"scenario": "SC-01"}\n' > "${TMP}/senza_turni.json"
  : > "${TMP}/args.log"
  out="$(prova giudica --conversazione "${gc}" --conversazione "${TMP}/senza_turni.json" --uscita "${TMP}/g40")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"turni"* ]] \
    && [[ "${out}" != *Traceback* ]] && [[ ! -s "${TMP}/args.log" ]]; then
    pass "giudica: una conversazione senza turni ferma tutto prima di ogni chiamata (rc 2)"
  else
    fail "giudica senza turni: rc=${rc}: ${out}"
  fi
  : > "${TMP}/args.log"
  out="$(prova giudica --conversazione "${gc}" --conversazione "${gc}" --uscita "${TMP}/g41")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"stesso id"* ]] \
    && [[ "${out}" != *Traceback* ]] && [[ ! -s "${TMP}/args.log" ]]; then
    pass "giudica: due conversazioni con lo stesso id si fermano prima di ogni chiamata (rc 2)"
  else
    fail "giudica id doppi: rc=${rc}: ${out}"
  fi
  mkdir -p "${TMP}/c42"
  local sc
  sc="$(printf '%s' "${PROJ}"/scenari/sc-01-*.json)"
  out="$(prova conversazione --versione "${PROJ}/v0" --scenario "${sc}" --uscita "${TMP}/c42")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"${TMP}/c42 esiste già: cancellatela e rilanciate con lo stesso nome"* ]] \
    && [[ "${out}" != *"scegliete"* ]]; then
    pass "conversazione: una cartella già usata dice di cancellarla e rilanciare (rc 2)"
  else
    fail "conversazione già usata: rc=${rc}: ${out}"
  fi
}

test_confronta_esito_senza_campi() {
  local a="${TMP}/ca" b="${TMP}/cb" out rc
  mkdir -p "${a}/C1" "${b}/C1"
  printf '{"completa": true, "errore": false, "chiamate": []}\n' > "${a}/C1/esito.json"
  printf '{"completa": true, "errore": false, "soddisfatte": 1, "totale": 2, "chiamate": []}\n' > "${b}/C1/esito.json"
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"soddisfatte"* ]] && [[ "${out}" != *Traceback* ]]; then
    pass "confronta: un esito senza i campi è una precondizione (rc 2), mai un traceback"
  else
    fail "confronta esito senza campi: rc=${rc}: ${out}"
  fi
  printf '[1]\n' > "${a}/C1/esito.json"
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" != *Traceback* ]]; then
    pass "confronta: un esito che non è un oggetto è una precondizione (rc 2)"
  else
    fail "confronta esito non oggetto: rc=${rc}: ${out}"
  fi
}

test_mai_un_traceback() {
  local out rc
  out="$(py 2>&1 <<'EOF'
import contextlib, io, sys
import prova, confronta
def boom(*a): raise RuntimeError("scoppiato")
prova.comando_casi = boom
err = io.StringIO()
with contextlib.redirect_stderr(err):
    rc = prova.main(["casi", "--versione", "x", "--uscita", "y"])
assert rc == 2 and "scoppiato" in err.getvalue() and err.getvalue().count("\n") == 1, err.getvalue()
confronta._carica = boom
sys.argv = ["confronta.py", "a", "b"]
err = io.StringIO()
with contextlib.redirect_stderr(err):
    rc = confronta.main()
assert rc == 2 and "scoppiato" in err.getvalue() and err.getvalue().count("\n") == 1, err.getvalue()
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "prova.py e confronta.py: un errore inatteso è una riga e uscita 2, mai un traceback"
  else
    fail "mai un traceback: rc=${rc}: ${out}"
  fi
}

# L'ambiente ripulito lascia passare proxy, certificati e CLAUDE_CONFIG_DIR,
# mai la chiave; e la sessione salvata si cancella dove sta davvero.
test_ambiente() {
  local casi="${TMP}/casi50" u="${TMP}/u50" out rc
  scrivi_casi "${casi}"
  : > "${TMP}/env.log"
  modo sessione
  mkdir -p "${TMP}/cfg"
  out="$(env PATH="${TMP}/bin:${PATH}" HTTPS_PROXY=http://proxy-finto:3128 \
    HTTP_PROXY=http://p:1 NO_PROXY=localhost https_proxy=http://p:2 \
    http_proxy=http://p:3 no_proxy=127.0.0.1 NODE_EXTRA_CA_CERTS=/ca.pem \
    SSL_CERT_FILE=/cert.pem CLAUDE_CONFIG_DIR="${TMP}/cfg" \
    ANTHROPIC_API_KEY=valore-finto \
    python3 -B -I "${BANCO}/prova.py" casi --versione "${PROJ}/v0" \
    --casi "${casi}" --uscita "${u}" 2>&1)"
  rc=$?
  modo ok
  if (( rc == 0 )) && python3 -B -I - "${TMP}/env.log" 2>/dev/null <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
assert righe, "nessuna chiamata"
for e in righe:
    assert e["HTTPS_PROXY"] == "http://proxy-finto:3128" and e["HTTP_PROXY"] == "http://p:1"
    assert e["NO_PROXY"] == "localhost" and e["https_proxy"] == "http://p:2"
    assert e["http_proxy"] == "http://p:3" and e["no_proxy"] == "127.0.0.1"
    assert e["NODE_EXTRA_CA_CERTS"] == "/ca.pem" and e["SSL_CERT_FILE"] == "/cert.pem"
    assert e["CLAUDE_CONFIG_DIR"], e
    assert e["ANTHROPIC_API_KEY"] is None
PY
  then
    pass "ambiente: proxy, certificati e CLAUDE_CONFIG_DIR passano a claude, la chiave no"
  else
    fail "ambiente di claude: rc=${rc}: ${out}"
  fi
  if [[ "$(cat "${TMP}/uv_env.log")" == "http://proxy-finto:3128 no" ]]; then
    pass "ambiente: il proxy arriva anche a uv, la chiave no"
  else
    fail "ambiente di uv: $(cat "${TMP}/uv_env.log")"
  fi
  if [[ -d "${TMP}/cfg/projects" ]] \
    && [[ -z "$(command find "${TMP}/cfg/projects" -mindepth 1 -print -quit)" ]]; then
    pass "ambiente: la sessione salvata si cancella anche sotto CLAUDE_CONFIG_DIR"
  else
    fail "ambiente: sessione rimasta: $(command find "${TMP}/cfg" | head -5)"
  fi
}

test_niente_pycache() {
  local copia="${TMP}/copia_p" casi="${TMP}/casi60" out rc
  scrivi_casi "${casi}"
  mkdir -p "${copia}"
  cp -R "${PROJ}" "${copia}/assistenza"
  out="$(env PATH="${TMP}/bin:${PATH}" python3 "${copia}/assistenza/banco/prova.py" \
    casi --versione "${copia}/assistenza/v0" --casi "${casi}" \
    --uscita "${TMP}/u60" 2>&1)"
  rc=$?
  if (( rc == 0 )) && [[ ! -e "${copia}/assistenza/banco/__pycache__" ]]; then
    pass "prova.py senza -B non lascia __pycache__ nel banco"
  else
    fail "prova.py senza -B: rc=${rc}: ${out}; $(ls "${copia}/assistenza/banco")"
  fi
  out="$(python3 "${copia}/assistenza/banco/confronta.py" "${TMP}/u60" "${TMP}/u60" 2>&1)"
  rc=$?
  if (( rc == 0 )) && [[ ! -e "${copia}/assistenza/banco/__pycache__" ]]; then
    pass "confronta.py senza -B non lascia __pycache__ nel banco"
  else
    fail "confronta.py senza -B: rc=${rc}: ${out}"
  fi
}

test_codifica_e_orologio() {
  local out rc
  out="$(python3 -B -I - "${BANCO}/prova.py" 2>&1 <<'PY'
import ast, sys
albero = ast.parse(open(sys.argv[1], encoding="utf-8").read())
chiamate = [n for n in ast.walk(albero) if isinstance(n, ast.Call)
            and isinstance(n.func, ast.Attribute) and n.func.attr == "run"
            and any(k.arg == "text" for k in n.keywords)]
assert len(chiamate) == 2, len(chiamate)
for c in chiamate:
    argomenti = {k.arg: k.value for k in c.keywords}
    assert isinstance(argomenti.get("encoding"), ast.Constant) \
        and argomenti["encoding"].value == "utf-8", c.lineno
print("ok")
PY
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "prova.py: le chiamate con text=True hanno encoding=\"utf-8\""
  else
    fail "encoding: rc=${rc}: ${out}"
  fi
}

# handson::run aspetta Invio su un terminale: questo strumento no, così tre
# comandi incollati insieme girano tutti e tre.
test_ingresso_senza_pausa() {
  local t="${ROOT}/tools/prova_assistente.sh" ws="${TMP}/ws_p" out rc
  mkdir -p "${ws}/progetti/assistenza-clienti/banco"
  cp "${BANCO}"/*.py "${ws}/progetti/assistenza-clienti/banco/"
  out="$(python3 -B -I - bash "${t}" "${ws}" confronta "${TMP}/non-c-e" "${TMP}/nemmeno" 2>&1 <<'PY'
import os, pty, subprocess, sys
padrone, schiavo = pty.openpty()
try:
    fatto = subprocess.run(sys.argv[1:], stdin=schiavo, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=8, check=False)
except subprocess.TimeoutExpired as exc:
    sys.stdout.write((exc.stdout or b"").decode("utf-8", "replace"))
    sys.exit(124)
sys.stdout.write(fatto.stdout.decode("utf-8", "replace"))
sys.exit(fatto.returncode)
PY
)"; rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"cartella assente"* ]] \
    && [[ "${out}" != *"[Invio per"* ]]; then
    pass "prova_assistente.sh: su un terminale non aspetta Invio"
  else
    fail "prova_assistente.sh sul terminale: rc=${rc}: ${out}"
  fi
}

test_schema() {
  local casi="${TMP}/casi9" u="${TMP}/u9" out rc
  scrivi_casi "${casi}"
  printf '{"type": "object"}\n' > "${TMP}/schema.json"
  : > "${TMP}/args.log"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${u}" --schema "${TMP}/schema.json")"
  rc=$?
  if (( rc == 0 )) && command grep -q -- '"--json-schema"' "${TMP}/args.log" \
    && python3 -B -I -c 'import json,sys
assert json.load(open(sys.argv[1]))["strutturato"]=={"coperta": True}' "${u}/CASO-A/esito.json" 2>/dev/null; then
    pass "casi: --schema arriva a claude e il campo finisce in esito.json"
  else
    fail "casi schema: rc=${rc}: ${out}"
  fi
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u10" --schema "${TMP}/non-c-e.json")"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"schema illeggibile"* ]]; then
    pass "casi: uno schema che manca è una precondizione (rc 2)"
  else
    fail "casi schema mancante: rc=${rc}: ${out}"
  fi
}

test_server_non_si_prepara() {
  local casi="${TMP}/casi11" out rc
  scrivi_casi "${casi}"
  touch "${TMP}/uv_rotto"
  out="$(prova casi --versione "${PROJ}/v0" --casi "${casi}" --uscita "${TMP}/u11")"
  rc=$?
  rm -f "${TMP}/uv_rotto"
  if (( rc == 2 )) && [[ "${out}" == *"il server non si prepara"* ]]; then
    pass "casi: se uv non prepara il server è una precondizione (rc 2)"
  else
    fail "casi uv rotto: rc=${rc}: ${out}"
  fi
}

test_regole_in_coda() {
  local v="${TMP}/v1" casi="${TMP}/casi4" u="${TMP}/u7" out rc
  mkdir -p "${v}"
  printf 'Sei un assistente.\n' > "${v}/system-prompt.md"
  cp "${PROJ}/v0/strumenti.json" "${v}/strumenti.json"
  printf 'Regola: passa all operatore.\n' > "${v}/regole-escalation.md"
  scrivi_casi "${casi}"
  out="$(prova casi --versione "${v}" --casi "${casi}" --uscita "${u}")"
  rc=$?
  if (( rc == 0 )) && [[ -f "${u}/CASO-A/system-prompt.usato.md" ]] \
    && command grep -q 'Regola: passa' "${u}/CASO-A/system-prompt.usato.md" \
    && command grep -q 'Sei un assistente' "${u}/CASO-A/system-prompt.usato.md"
  then
    pass "versione: le regole di escalation finiscono in coda al system prompt"
  else
    fail "regole in coda: rc=${rc}: ${out}"
  fi
}

test_conversazione() {
  local u="${TMP}/c1" out rc sc
  sc="$(printf '%s' "${PROJ}"/scenari/sc-01-*.json)"
  : > "${TMP}/args.log"
  out="$(prova conversazione --versione "${PROJ}/v0" --scenario "${sc}" --uscita "${u}" --giri 3)"
  rc=$?
  if (( rc == 0 )) && [[ -f "${u}/conversazione.json" && -f "${u}/trascrizione.md" ]]; then
    pass "conversazione: scrive la trascrizione e il JSON"
  else
    fail "conversazione: rc=${rc}: ${out}"
  fi
  if python3 -B -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
assert d["scenario"]=="SC-01"
t=d["turni"]; assert t[0]["ruolo"]=="cliente" and t[1]["ruolo"]=="assistente" and len(t)==2, t
assert t[1]["azioni"][0]["strumento"]=="stato_linea", t' "${u}/conversazione.json" 2>/dev/null; then
    pass "conversazione: il formato è quello di golden/, si ferma a FINE"
  else
    fail "conversazione: $(cat "${u}/conversazione.json")"
  fi
  if command grep -q -- '"--agent", "cliente"' "${TMP}/args.log" \
    && command grep -q -- '"haiku"' "${TMP}/args.log"; then
    pass "conversazione: la persona è l'agente cliente, su Haiku"
  else
    fail "conversazione: la persona: $(head -3 "${TMP}/args.log")"
  fi
}

test_giudica() {
  local u="${TMP}/g1" out rc gc
  gc="$(printf '%s' "${PROJ}"/golden/gc-01-*.json)"
  out="$(prova giudica --conversazione "${gc}" --uscita "${u}")"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == *"GC-01"*"18"*"superato"* ]] \
    && [[ -f "${u}/GC-01/verdetto.json" ]]; then
    pass "giudica: il totale e il verdetto li calcola il codice dalla rubrica"
  else
    fail "giudica: rc=${rc}: ${out}"
  fi
  if py > /dev/null 2>&1 <<'EOF'
import lib_banco as L
p = {"C%d" % i: 2 for i in range(1, 10)}
assert L.verdetto(p) == (18, "superato")
assert L.verdetto(dict(p, C6=1)) == (17, "non superato")
assert L.verdetto(dict(p, C1=0)) == (16, "non superato")
q = dict(p, C1=1, C2=1, C3=1, C4=1, C5=1)
assert L.verdetto(q) == (13, "non superato")
assert L.verdetto(dict(p, C1=None)) == (None, "non so")
EOF
  then
    pass "verdetto: C6 e C7 a 2, nessuno 0, almeno 14; un «non so» non si somma"
  else
    fail "verdetto: le regole della rubrica"
  fi
}

test_confronta() {
  local a="${TMP}/a" b="${TMP}/b" out rc
  scrivi_esito() {
    mkdir -p "$1/$2"
    printf '{"caso":"%s","versione":"%s","soddisfatte":%d,"totale":%d,"completa":%s,"errore":false,"token_prima_richiesta":100,"turni":2,"secondi":1.5,"chiamate":[]}\n' \
      "$2" "${1##*/}" "$3" "$4" "$5" > "$1/$2/esito.json"
  }
  scrivi_esito "${a}" C1 2 4 true
  scrivi_esito "${b}" C1 4 4 true
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == *"C1"*"2/4"*"4/4"* ]] \
    && [[ "${out}" == *"confermata in questa misura"* ]]; then
    pass "confronta: la seconda versione soddisfa di più"
  else
    fail "confronta migliore: rc=${rc}: ${out}"
  fi
  scrivi_esito "${b}" C1 2 4 true
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == *"non distinguibile"* ]] \
    && [[ "${out}" != *"smentita"* ]]; then
    pass "confronta: pari è non distinguibile, mai «smentita»"
  else
    fail "confronta pari: rc=${rc}: ${out}"
  fi
  scrivi_esito "${b}" C1 1 4 true
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == *"non confermata in questa misura"* ]]; then
    pass "confronta: meno è non confermata in questa misura, ed esce 0"
  else
    fail "confronta peggiore: rc=${rc}: ${out}"
  fi
  rm -rf "${b}/C1"
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 1 )) && [[ "${out}" == *"manca"* ]]; then
    pass "confronta: un caso che manca a una versione dà uscita 1"
  else
    fail "confronta mancante: rc=${rc}: ${out}"
  fi
  scrivi_esito "${b}" C1 4 4 false
  out="$(python3 -B -I "${BANCO}/confronta.py" "${a}" "${b}" 2>&1)"
  rc=$?
  if (( rc == 1 )) && [[ "${out}" == *"non è finita"* ]]; then
    pass "confronta: un'esecuzione incompleta dà uscita 1"
  else
    fail "confronta incompleta: rc=${rc}: ${out}"
  fi
  out="$(python3 -B -I "${BANCO}/confronta.py" "${TMP}/non-c-e" "${b}" 2>&1)"
  rc=$?
  if (( rc == 2 )); then
    pass "confronta: una cartella che manca è una precondizione (rc 2)"
  else
    fail "confronta precondizione: rc=${rc}: ${out}"
  fi
}

test_casi_forniti() {
  local out rc
  out="$(py 2>&1 <<EOF
import glob, json, pathlib
import lib_banco as L, motore
casi = sorted(glob.glob("${BANCO}/casi/*.json"))
assert len(casi) == 5, casi
ammesse = set(motore.CAPACITA)
for f in casi:
    c = L.carica_caso(pathlib.Path(f), pathlib.Path("${PROJ}/scenari"))
    a = c["asserzioni"]
    for k in ("deve_chiamare", "non_deve_chiamare"):
        assert set(a.get(k, [])) <= ammesse, (f, k)
    for p in a.get("prima_di", []):
        assert set(p) <= ammesse, (f, p)
print("ok")
EOF
)"; rc=$?
  if (( rc == 0 )) && [[ "${out}" == *ok* ]]; then
    pass "casi forniti: cinque, si caricano, nominano solo capacità esistenti"
  else
    fail "casi forniti: rc=${rc}: ${out}"
  fi
}

test_agenti_forniti() {
  local f
  for f in cliente giudice; do
    if [[ -f "${BANCO}/.claude/agents/${f}.md" ]] \
      && command grep -q '^<instructions>' "${BANCO}/.claude/agents/${f}.md"; then
      pass "agente ${f}: il corpo segue il template del corso"
    else
      fail "agente ${f}: manca o non segue il template"
    fi
  done
  if command grep -q '^tools: ""' "${BANCO}/.claude/agents/cliente.md"; then
    pass "agente cliente: nessuno strumento"
  else
    fail "agente cliente: dovrebbe avere tools vuoto"
  fi
  # Con tools vuoto nel frontmatter --json-schema non produce
  # structured_output: lo strumento delle uscite strutturate sparisce.
  if ! command grep -q '^tools:' "${BANCO}/.claude/agents/giudice.md"; then
    pass "agente giudice: nessuna riga tools, gli strumenti li toglie --tools"
  else
    fail "agente giudice: una riga tools toglie anche le uscite strutturate"
  fi
}

test_ingresso() {
  local t="${ROOT}/tools/prova_assistente.sh" out rc
  out="$(bash "${t}" 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"Uso"* ]]; then
    pass "prova_assistente.sh: senza argomenti stampa l'uso e esce 2"
  else
    fail "ingresso senza argomenti: rc=${rc}: ${out}"
  fi
  out="$(bash "${t}" "${TMP}/non-c-e" casi 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"spazio di lavoro"* ]]; then
    pass "prova_assistente.sh: uno spazio di lavoro che manca esce 2"
  else
    fail "ingresso spazio: rc=${rc}: ${out}"
  fi
  mkdir -p "${TMP}/vuoto"
  out="$(bash "${t}" "${TMP}/vuoto" casi 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"banco"* ]]; then
    pass "prova_assistente.sh: uno spazio senza il banco esce 2"
  else
    fail "ingresso senza banco: rc=${rc}: ${out}"
  fi
}

test_motore
test_scheda_e_copertura
test_definizioni
test_asserzioni
test_stream
test_stream_server
test_casi_ok
test_casi_rotti
test_versione_prima_di_tutto
test_casi_malformati
test_id_doppi
test_server_che_non_parte
test_registro_rotto
test_scenario_e_conversazioni_malformati
test_confronta_esito_senza_campi
test_mai_un_traceback
test_ambiente
test_niente_pycache
test_codifica_e_orologio
test_ingresso_senza_pausa
test_regole_in_coda
test_server_non_si_prepara
test_schema
test_conversazione
test_giudica
test_confronta
test_casi_forniti
test_agenti_forniti
test_ingresso

echo "PASS=${PASS} FAIL=${FAIL}"
(( FAIL == 0 )) || exit 1
