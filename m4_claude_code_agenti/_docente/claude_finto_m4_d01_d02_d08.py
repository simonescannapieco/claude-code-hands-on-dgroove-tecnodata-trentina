#!/usr/bin/env python3
"""claude_finto_m4_d01_d02_d08.py -- un claude finto per le prove di M4-D01,
M4-D02 e M4-D08 (test_m4_d01.sh, test_m4_d02.sh, test_m4_d08.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
live.sh, i verifica.sh e i blocchi dei README girano per intero senza
chiamare il modello e senza toccare un account. Ogni stato, ogni stream e
ogni risposta sono scritti qui, inventati e dichiarati finti: nessuno viene
da Claude né da un account vero.

Che cosa fa, secondo gli argomenti:
  --version                    una versione finta;
  auth status [--json|--text]  (M4-D01) uno stato d'accesso finto, con campi
      che somigliano a un'identità (persona@example.org, «Org di prova»): le
      prove controllano che non arrivino mai a schermo né nei file. Con
      ANTHROPIC_API_KEY nell'ambiente authMethod vale «api_key», con
      apiKeySource FINTO_FONTE (default «ANTHROPIC_API_KEY»), salvo
      FINTO_AUTH_CON (per esempio «claude.ai»: la chiave ignorata); senza,
      FINTO_AUTH (default «claude.ai»; «none» = non collegato, uscita 1).
      FINTO_AUTH_ROTTO=1 stampa un testo che non è JSON, con l'e-mail finta;
  mcp get <nome>               (M4-D02) FINTO_MCP_GET=ok (default): un testo
      finto con lo stato, uscita 0; un numero n: un errore finto della CLI
      su STDERR, uscita n; altrimenti «No MCP server found…» su STDERR,
      uscita 1; mcp add … e mcp remove <nome> stampano una riga finta ed
      escono 0;
  -p … --output-format stream-json --verbose   (M4-D02) uno stream finto:
      l'evento init con i server di --mcp-config (e, senza
      --strict-mcp-config, un connettore finto in più) nello stato
      FINTO_STATO (default «connected»), gli strumenti (per ogni server
      collegato mcp__<server>__cerca_copertura, oppure
      FINTO_NOME_STRUMENTO); se il server copertura è collegato e
      FINTO_CHIAMA non è «0», una chiamata allo strumento (con il nome
      FINTO_NOME_USO, se c'è), preceduta da un ToolSearch se ToolSearch è
      fra gli strumenti integrati (non con --tools Read); poi la risposta,
      FINTO_RISPOSTA_CON (default i comuni con la fibra) o
      FINTO_RISPOSTA_SENZA, e il risultato, che FINTO_TRONCO=1 toglie;
  -p … --output-format json    (M4-D08) legge lo STDIN: oltre FINTO_TETTO
      byte (default 10485760; 0 = nessun tetto) esce 1 con un errore finto
      su STDERR, oppure su STDOUT come JSON d'errore con
      FINTO_TETTO_SU=stdout, oppure senza messaggio con FINTO_TETTO_MUTO=1;
      altrimenti il JSON del risultato con FINTO_RISPOSTA_PIPE.
  FINTO_ESITO=ko               esce 1 senza stampare nulla (non per
                               --version).
Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: gli argomenti,
la chiave (null; «finta» se è la chiave finta del corso; «altra»: mai il
valore), il nome della cartella corrente e il suo contenuto (ciò che la
sessione vedrebbe lì), e i byte letti da STDIN (null se non lo legge).
Un'opzione che non conosce la rifiuta («error: unknown option», uscita 1).
Uscita: 0 risposta · 1 FINTO_ESITO=ko, un rifiuto, un accesso che non c'è,
        un errore finto
"""
import json
import os
import sys
from typing import Dict, List, Optional, Tuple

CHIAVE_FINTA = "finta-chiave-del-corso"
# Le opzioni dei tre elementi e quanti valori prendono; -1 = un elenco,
# come --mcp-config: i valori fino alla prossima parola che comincia con -.
OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--tools": 1, "--allowedTools": 1, "--output-format": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--mcp-config": -1}
FORMATI = ("text", "json", "stream-json")
TETTO = 10 * 1024 * 1024
INTEGRATI = ["Task", "Bash", "Edit", "Read", "ToolSearch", "WebFetch",
             "WebSearch", "Write"]
COMUNI_FTTH = ("Ala", "Arco", "Baselga di Pinè", "Borgo Valsugana",
               "Caldonazzo", "Lavis", "Levico Terme", "Mezzolombardo",
               "Mori", "Pergine Valsugana", "Riva del Garda", "Rovereto",
               "Trento")
SENZA = ("Risposta finta del claude finto: non ho accesso ai dati di "
         "copertura di CiaspoLink.")
PIPE = "inizio 10:12 | fine 11:40"
ERRORE_TETTO = ("Errore finto del claude finto: l'ingresso in pipe supera "
                "il tetto di 10 MB")


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def registra(argv: List[str], letti: Optional[int]) -> None:
    """Una riga in FINTO_LOG, se c'è: anche ciò che c'è nella cartella
    corrente, come la vedrebbe la sessione (null se non si elenca)."""
    log = os.environ.get("FINTO_LOG")
    if not log:
        return
    chiave = os.environ.get("ANTHROPIC_API_KEY")
    if chiave:
        chiave = "finta" if chiave == CHIAVE_FINTA else "altra"
    try:
        elenco: Optional[List[str]] = sorted(os.listdir("."))
    except OSError:
        elenco = None
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({"argv": argv, "chiave": chiave or None,
                             "cartella": os.path.basename(os.getcwd()),
                             "elenco": elenco, "stdin": letti},
                            ensure_ascii=False) + "\n")


def argomenti(argv: List[str]) -> Tuple[Dict[str, List[str]], List[str]]:
    """(le opzioni con i loro valori, gli operandi) di una chiamata -p."""
    opzioni: Dict[str, List[str]] = {}
    operandi: List[str] = []
    i = 0
    while i < len(argv):
        parola = argv[i]
        if parola == "--":
            operandi += argv[i + 1:]
            break
        if not parola.startswith("-"):
            operandi.append(parola)
            i += 1
            continue
        if parola not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % parola)
        quanti = OPZIONI[parola]
        valori: List[str] = []
        i += 1
        if quanti < 0:
            while i < len(argv) and not argv[i].startswith("-"):
                valori.append(argv[i])
                i += 1
        else:
            valori = argv[i:i + quanti]
            i += quanti
        if len(valori) < max(quanti, 1) and quanti != 0:
            raise Rifiutato("error: option '%s' argument missing" % parola)
        opzioni[parola] = valori
    return opzioni, operandi


def stato_accesso() -> Tuple[dict, int]:
    """Lo stato d'accesso finto e l'uscita di auth status."""
    chiave = os.environ.get("ANTHROPIC_API_KEY")
    if chiave:
        metodo = os.environ.get("FINTO_AUTH_CON", "api_key")
    else:
        metodo = os.environ.get("FINTO_AUTH", "claude.ai")
    collegato = metodo != "none"
    doc = {"loggedIn": collegato, "authMethod": metodo,
           "apiProvider": "firstParty", "email": "persona@example.org",
           "orgId": "00000000-0000-0000-0000-000000000000",
           "orgName": "Org di prova", "subscriptionType": "pro"}
    if chiave and metodo == "api_key":
        doc["apiKeySource"] = os.environ.get("FINTO_FONTE",
                                             "ANTHROPIC_API_KEY")
    return doc, 0 if collegato else 1


def auth(argv: List[str]) -> int:
    """claude auth status [--json|--text]."""
    if argv[:1] != ["status"] or any(a not in ("--json", "--text")
                                     for a in argv[1:]):
        raise Rifiutato("error: unknown command 'auth %s'" % " ".join(argv))
    doc, uscita = stato_accesso()
    if os.environ.get("FINTO_AUTH_ROTTO") == "1":
        print("Stato finto, non JSON: persona@example.org")
    elif "--text" in argv:
        print("Login method: %s\nEmail: %s" % (doc["authMethod"],
                                              doc["email"]))
    else:
        print(json.dumps(doc, indent=2))
    return uscita


def mcp(argv: List[str]) -> int:
    """claude mcp get <nome>; claude mcp add … e claude mcp remove <nome>
    rispondono con una riga finta (le prove ne leggono gli argomenti nel
    registro)."""
    if argv[:1] == ["add"] and len(argv) >= 3:
        print("Server MCP finto aggiunto (claude finto): %s" % argv[1])
        return 0
    if argv[:1] == ["remove"] and len(argv) == 2:
        print("Server MCP finto tolto (claude finto): %s" % argv[1])
        return 0
    if len(argv) != 2 or argv[0] != "get":
        raise Rifiutato("error: unknown command 'mcp %s'" % " ".join(argv))
    esito = os.environ.get("FINTO_MCP_GET", "ok")
    if esito == "ok":
        print("%s:\n  Scope: Local config (finto)\n  Status: ✓ Connected "
              "(finto)\n  Type: stdio\n  Command: uv\n  Environment:\n"
              "    COPERTURA_DATI=/percorso/finto/database" % argv[1])
        return 0
    if esito.isdigit():
        sys.stderr.write("Errore finto della CLI (claude finto)\n")
        return int(esito)
    sys.stderr.write("No MCP server found with name: %s (claude finto)\n"
                     % argv[1])
    return 1


def server_dichiarati(valori: List[str]) -> Dict[str, dict]:
    """I server dei file (o delle stringhe JSON) di --mcp-config."""
    server: Dict[str, dict] = {}
    for valore in valori:
        testo = valore
        if not valore.lstrip().startswith("{"):
            try:
                with open(valore, encoding="utf-8") as fh:
                    testo = fh.read()
            except OSError:
                raise Rifiutato("error: MCP config file not found: %s"
                                % valore)
        try:
            doc = json.loads(testo)
        except ValueError:
            raise Rifiutato("error: invalid MCP config: %s" % valore)
        dichiarati = doc.get("mcpServers") if isinstance(doc, dict) else None
        if not isinstance(dichiarati, dict):
            raise Rifiutato("error: invalid MCP config: %s" % valore)
        server.update(dichiarati)
    return server


def risultato(testo: str, turni: int, ingresso: int) -> dict:
    """Il messaggio del risultato, come in claude -p."""
    return {"type": "result", "subtype": "success", "is_error": False,
            "result": testo, "num_turns": turni,
            "session_id": "sessione-finta", "permission_denials": [],
            "usage": {"input_tokens": ingresso, "output_tokens": 5,
                      "cache_creation_input_tokens": 0,
                      "cache_read_input_tokens": 0}}


def assistente(blocco: dict) -> dict:
    """Un messaggio dell'assistente con un blocco."""
    return {"type": "assistant", "parent_tool_use_id": None,
            "message": {"role": "assistant", "content": [blocco]}}


def utente(ident: str, contenuto: str) -> dict:
    """Il risultato di uno strumento."""
    return {"type": "user", "parent_tool_use_id": None,
            "message": {"role": "user", "content": [{
                "type": "tool_result", "tool_use_id": ident,
                "content": contenuto}]}}


def strumenti_integrati(opzioni: Dict[str, List[str]]) -> List[str]:
    """Gli strumenti integrati: quelli di --tools, o un elenco finto."""
    if "--tools" not in opzioni:
        return list(INTEGRATI)
    valore = opzioni["--tools"][0]
    return [n for n in valore.replace(",", " ").split() if n]


def stream(opzioni: Dict[str, List[str]]) -> List[dict]:
    """Gli eventi dello stream finto di M4-D02."""
    dichiarati = server_dichiarati(opzioni.get("--mcp-config", []))
    stato = os.environ.get("FINTO_STATO", "connected")
    sessione = [{"name": n, "status": stato, "source": "dynamic"}
                for n in sorted(dichiarati)]
    if "--strict-mcp-config" not in opzioni:
        sessione.append({"name": "claude.ai Finto", "status": "pending",
                         "source": "claudeai"})
    strumenti = strumenti_integrati(opzioni)
    for voce in sessione:
        if voce["status"] == "connected" and voce["source"] == "dynamic":
            strumenti.append(os.environ.get(
                "FINTO_NOME_STRUMENTO",
                "mcp__%s__cerca_copertura" % voce["name"]))
    eventi = [{"type": "system", "subtype": "init",
               "session_id": "sessione-finta", "model": "claude-finto",
               "cwd": "/percorso/finto", "tools": strumenti,
               "mcp_servers": sessione, "apiKeySource": "none",
               "claude_code_version": "0.0.0-finto"}]
    collegato = "copertura" in dichiarati and stato == "connected"
    if collegato and os.environ.get("FINTO_CHIAMA", "1") != "0":
        nome = os.environ.get("FINTO_NOME_USO",
                              "mcp__copertura__cerca_copertura")
        if "ToolSearch" in strumenti:
            eventi += [
                assistente({"type": "tool_use", "id": "toolu_finto_0",
                            "name": "ToolSearch",
                            "input": {"query": "select:" + nome}}),
                utente("toolu_finto_0", "riferimento finto")]
        eventi += [
            assistente({"type": "tool_use", "id": "toolu_finto_1",
                        "name": nome, "input": {"tecnologia": "FTTH"}}),
            utente("toolu_finto_1", "risultato finto")]
    if "copertura" in dichiarati:
        testo = os.environ.get("FINTO_RISPOSTA_CON", "\n".join(COMUNI_FTTH))
    else:
        testo = os.environ.get("FINTO_RISPOSTA_SENZA", SENZA)
    eventi.append(assistente({"type": "text", "text": testo}))
    if os.environ.get("FINTO_TRONCO") != "1":
        eventi.append(risultato(testo, len(eventi), 9))
    return eventi


def pipe(dati: bytes) -> int:
    """La risposta di M4-D08: l'errore finto oltre il tetto, o il JSON."""
    tetto = int(os.environ.get("FINTO_TETTO", str(TETTO)))
    if tetto > 0 and len(dati) > tetto:
        if os.environ.get("FINTO_TETTO_MUTO") == "1":
            return 1
        if os.environ.get("FINTO_TETTO_SU") == "stdout":
            print(json.dumps({"type": "result",
                              "subtype": "error_during_execution",
                              "is_error": True, "result": ERRORE_TETTO},
                             ensure_ascii=False))
            return 1
        sys.stderr.write(ERRORE_TETTO + "\n")
        return 1
    testo = os.environ.get("FINTO_RISPOSTA_PIPE", PIPE)
    print(json.dumps(risultato(testo, 1, len(dati) // 4),
                     ensure_ascii=False))
    return 0


def stampa(argv: List[str]) -> int:
    """claude -p: lo stream di M4-D02 o il JSON di M4-D08. Legge lo STDIN
    soltanto con --output-format json (M4-D08, dove lo STDIN è la prova):
    le altre chiamate non aspettano un ingresso che può non chiudersi."""
    try:
        opzioni, operandi = argomenti(argv)
    except Rifiutato:
        registra(argv, None)
        raise
    formato = (opzioni.get("--output-format") or ["text"])[0]
    letti: Optional[int] = None
    dati = b""
    if formato == "json" and not sys.stdin.isatty():
        dati = sys.stdin.buffer.read()
        letti = len(dati)
    registra(argv, letti)
    if len(operandi) != 1:
        raise Rifiutato("error: %s" % (
            "too many arguments" if operandi else "missing prompt"))
    if formato not in FORMATI:
        raise Rifiutato("error: unknown output format '%s'" % formato)
    if formato == "stream-json" and "--verbose" not in opzioni:
        raise Rifiutato("error: il claude finto vuole --verbose con "
                        "--output-format stream-json")
    if os.environ.get("FINTO_ESITO", "ok") != "ok":
        return 1
    if formato == "stream-json":
        for evento in stream(opzioni):
            print(json.dumps(evento, ensure_ascii=False))
        return 0
    if formato == "json":
        return pipe(dati)
    print(os.environ.get("FINTO_RISPOSTA_PIPE", PIPE))
    return 0


def main(argv: List[str]) -> int:
    try:
        if argv[:1] in (["-p"], ["--print"]):
            return stampa(argv)
        registra(argv, None)
        if argv[:1] == ["--version"]:
            print("0.0.0 (Claude Code, finto)")
            return 0
        if os.environ.get("FINTO_ESITO", "ok") != "ok":
            return 1
        if argv[:1] == ["auth"]:
            return auth(argv[1:])
        if argv[:1] == ["mcp"]:
            return mcp(argv[1:])
        raise Rifiutato("error: il claude finto non conosce: %s"
                        % " ".join(argv))
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
