#!/usr/bin/env python3
"""claude_finto_m4_e03.py -- un claude finto per le prove di M4-E03
(test_m4_e03.sh).

La suite lo copia, con il nome «claude», davanti nel PATH: così
_docente/live.sh dell'elemento gira per intero senza chiamare il modello e
senza consumare il piano. Le risposte e le trascrizioni che scrive sono
inventate e dichiarate finte: nessuna è di Claude. Gli effetti sui file (la
documentazione, il test, la nota, il piano, la proposta, i commit) li
produce il finto stesso, come li produrrebbe una sessione: provano i
controlli, non il modello.

Gli argomenti: le opzioni di handson::claude_p e di live.sh (OPZIONI, con
quanti valori prendono), poi «--» e il prompt. Un'opzione che non conosce la
rifiuta («error: unknown option», uscita 1), come un --output-format che non
è json né stream-json, o stream-json senza --verbose. «--version» stampa una
versione finta.

Ogni invocazione aggiunge a FINTO_LOG (obbligatorio, tranne --version) una
riga JSON: argv, cwd, chiave (se ANTHROPIC_API_KEY era nell'ambiente). Il
numero della chiamata è il numero di righe del registro. Una chiamata senza
--resume apre la sessione «sessione-finta-<numero>», con --resume continua
quella data. La risposta è un JSON come quello di
`claude -p --output-format json`; con stream-json, lo stream: l'avvio, un
messaggio, il risultato (3 turni, 1000+n ms, 1110 token in entrata e 50 in
uscita) e, quando la chiamata ha avviato i subagent Explore, che lavorano in
background, la loro notifica e un secondo risultato (2 turni, 500 ms, 555 e
25; result_index 1, origin task-notification).

Le trascrizioni, solo se c'è PN_CLAUDE_DIR (mai in ~/.claude): la cartella
del progetto è PN_CLAUDE_DIR/projects/<la cartella corrente, ogni carattere
che non è lettera o cifra cambiato in «-»>; la sessione in <id>.jsonl, ogni
subagent in <id>/subagents/agent-<agentId>.jsonl.

Le scene, dal prompt:
  «due subagent Explore»        due chiamate Agent (Explore) nello stesso
                                messaggio, con le trascrizioni dei subagent;
                                FINTO_E03_AGENT=nessuno: nessuna chiamata
  «Scrivi la documentazione»    la documentazione e un commit;
                                FINTO_E03_DOC = buona (default) ·
                                senza_rischi · no; FINTO_E03_COMMIT =
                                senza_doc: il file senza il commit
  «Scrivi i test di caratterizzazione»  il test e un commit;
                                FINTO_E03_TEST = caratterizza (default, nessun
                                segno) · debole · rosso · no;
                                FINTO_E03_LEGACY=tocca: cambia anche il modulo
                                legacy (come un comando di shell)
  «Esegui di nuovo i test»      riscrive il test senza segni (salvo
                                FINTO_E03_MAI=1)
  «Scrivi NOTA.md»              NOTA.md e un commit
  «Proponi il refactoring»      con --permission-mode plan: il piano nella
                                cartella di plansDirectory (se le impostazioni
                                l'hanno) e una chiamata ExitPlanMode; senza
                                plan mode, niente
  «Il piano è approvato»        PROPOSTA.md e un commit; FINTO_E03_PROPOSTA =
                                buona (default) · senza_controlli
  «la verifica dello spazio di lavoro dice» (maiuscole o minuscole: apre
                                il tag <context> della correzione)  riscrive
                                buone documentazione, test e proposta, con
                                un commit (salvo FINTO_E03_MAI=1); legacy/
                                non lo tocca
  FINTO_ESITO=ko                esce 1 senza stampare nulla;
  FINTO_KO_ALLA=<n>             lo stesso, solo alla chiamata n.
Uscita: 0 risposta · 1 FINTO_ESITO=ko, FINTO_KO_ALLA o un argomento rifiutato
"""
import json
import os
import re
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--strict-mcp-config": 0,
           "--model": 1, "--effort": 1, "--allowedTools": 1,
           "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1,
           "--resume": 1, "--verbose": 0}
PROGETTO = "progetti/gestionale-php"
DOC = PROGETTO + "/docs/chiusura_mese.md"
TEST = PROGETTO + "/tests/Integrazione/ChiusuraMeseTest.php"
MODULO = PROGETTO + "/legacy/chiusura_mese.inc.php"
SEZIONI = ("Che cosa fa", "Ingressi e uscite", "Tabelle lette e scritte",
           "Effetti collaterali", "Le sei responsabilità", "Rischi")
TABELLE = ("fatture, righe_fattura, clienti, linee, ticket, provvigioni, "
           "attivazioni, offerte, registro_operazioni")
COMANDO = ("tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit "
           "-c progetti/gestionale-php")
# Quanti subagent ha avviato questa chiamata: lavorano in background, e
# allora lo stream ha un secondo risultato.
SUBAGENTI = []  # type: List[str]


def leggi_argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """Le opzioni (nome -> valore, "" se senza valore) e il prompt."""
    opzioni = {}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            return opzioni, " ".join(argv[i + 1:])
        if arg not in OPZIONI:
            raise ValueError("error: unknown option '%s'" % arg)
        quanti = OPZIONI[arg]
        if i + quanti >= len(argv) and quanti:
            raise ValueError("error: option '%s' argument missing" % arg)
        opzioni[arg] = argv[i + 1] if quanti else ""
        i += 1 + quanti
    raise ValueError("error: prompt mancante dopo «--»")


def registra(argv: List[str]) -> int:
    """Una riga nel registro; il numero della chiamata."""
    log = os.environ["FINTO_LOG"]
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({"argv": argv, "cwd": os.getcwd(),
                             "chiave": "ANTHROPIC_API_KEY" in os.environ},
                            ensure_ascii=False) + "\n")
    with open(log, encoding="utf-8") as fh:
        return sum(1 for _ in fh)


def scrivi(percorso: str, testo: str) -> None:
    cartella = os.path.dirname(percorso)
    if cartella:
        os.makedirs(cartella, exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(testo)


def commit(file: List[str], messaggio: str) -> None:
    """git add e git commit, come li eseguirebbe Claude con Bash."""
    if not os.path.isdir(".git"):
        return
    subprocess.run(["git", "add", "--"] + file, check=True)
    if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode == 0:
        return
    subprocess.run(["git", "-c", "user.name=Claude finto",
                    "-c", "user.email=finto@example.org",
                    "-c", "commit.gpgsign=false", "commit", "-q",
                    "-m", messaggio], check=True)


def trascrizione(sessione: str, righe: List[dict]) -> None:
    """Righe in fondo alla trascrizione della sessione (solo PN_CLAUDE_DIR)."""
    base = os.environ.get("PN_CLAUDE_DIR")
    if not base:
        return
    nome = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    cartella = os.path.join(base, "projects", nome)
    os.makedirs(cartella, exist_ok=True)
    with open(os.path.join(cartella, sessione + ".jsonl"), "a",
              encoding="utf-8") as fh:
        for riga in righe:
            fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


def subagente(sessione: str, numero: int) -> None:
    """La trascrizione finta di un subagent."""
    base = os.environ.get("PN_CLAUDE_DIR")
    if not base:
        return
    nome = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    cartella = os.path.join(base, "projects", nome, sessione, "subagents")
    scrivi(os.path.join(cartella, "agent-finto%d.jsonl" % numero),
           json.dumps({"type": "user", "isSidechain": True,
                       "message": {"role": "user",
                                   "content": "compito finto"}}) + "\n")


def strumento(n: int, k: int, nome: str, entrata: dict) -> dict:
    return {"type": "tool_use", "id": "toolu_finto_%d_%d" % (n, k),
            "name": nome, "input": entrata}


def messaggio(sessione: str, n: int, blocchi: List[dict]) -> dict:
    return {"type": "assistant", "isSidechain": False, "sessionId": sessione,
            "message": {"id": "msg_finto_%d" % n, "role": "assistant",
                        "content": blocchi}}


def mappa(sessione: str, n: int) -> str:
    if os.environ.get("FINTO_E03_AGENT") == "nessuno":
        return "Ho letto il modulo da solo (finto)."
    chiamate = [strumento(n, k, "Agent",
                          {"subagent_type": "Explore", "description": d,
                           "prompt": "compito finto"})
                for k, d in ((1, "chi chiama chiusura_mese"),
                             (2, "tabelle lette e scritte"))]
    trascrizione(sessione, [messaggio(sessione, n, chiamate)])
    subagente(sessione, 1)
    subagente(sessione, 2)
    SUBAGENTI.extend(["Explore", "Explore"])
    return "(a) bin/chiusura-mese.php:35 (finto) (b) tabelle (finto)"


def documentazione() -> str:
    variante = os.environ.get("FINTO_E03_DOC", "buona")
    if variante == "no":
        return "Non ho scritto la documentazione (finto)."
    testo = ["# chiusura_mese() (documentazione finta, del claude finto)", ""]
    for titolo in SEZIONI:
        if variante == "senza_rischi" and titolo == "Rischi":
            continue
        testo += ["## " + titolo, ""]
        if titolo == "Tabelle lette e scritte":
            testo += ["Tabelle (finto): " + TABELLE + ".", ""]
        elif titolo == "Le sei responsabilità":
            testo += ["%d. responsabilità finta" % k for k in range(1, 7)]
            testo += [""]
        else:
            testo += ["Testo finto.", ""]
    scrivi(DOC, "\n".join(testo))
    if os.environ.get("FINTO_E03_COMMIT") != "senza_doc":
        commit([DOC], "docs(legacy): documentazione finta")
    return "Documentazione scritta (finto)."


def test(seguito: bool) -> str:
    variante = os.environ.get("FINTO_E03_TEST", "caratterizza")
    if seguito:
        if os.environ.get("FINTO_E03_MAI") == "1":
            return "Non riesco a farli passare (finto)."
        variante = "caratterizza"
    if variante == "no":
        return "Non ho scritto il test (finto)."
    righe = ["<?php", "// Test finto del claude finto delle prove di M4-E03:",
             "// non è PHP vero; il php.sh finto lo giudica dai segni."]
    if variante in ("debole", "rosso"):
        righe.append("// FINTO: " + variante)
    scrivi(TEST, "\n".join(righe) + "\n")
    if os.environ.get("FINTO_E03_LEGACY") == "tocca":
        with open(MODULO, "a", encoding="utf-8") as fh:
            fh.write("// ritocco finto\n")
    commit([TEST], "test(legacy): test finto")
    return "Test scritto ed eseguito con %s (finto)." % COMANDO


def nota() -> str:
    scrivi("NOTA.md", "# Nota (finta)\n\nFatto: tutto (finto).\n")
    commit(["NOTA.md"], "docs: nota finta")
    return "Nota scritta (finto)."


def cartella_piani() -> Optional[str]:
    try:
        with open(".claude/settings.json", encoding="utf-8") as fh:
            valore = json.load(fh).get("plansDirectory")
    except (OSError, ValueError, AttributeError):
        return None
    return valore if isinstance(valore, str) and valore else None


def piano(sessione: str, n: int, modo: str) -> str:
    if modo != "plan":
        return "Fuori da plan mode non preparo il piano (finto)."
    cartella = cartella_piani()
    if cartella:
        scrivi(os.path.join(cartella, "piano-finto.md"), "# Piano finto\n")
    trascrizione(sessione, [messaggio(sessione, n, [
        strumento(n, 1, "ExitPlanMode", {"plan": "piano finto"})])])
    return "Ecco il piano (finto)."


def proposta() -> str:
    senza = os.environ.get("FINTO_E03_PROPOSTA") == "senza_controlli"
    righe = ["# Proposta di refactoring (finta)", ""]
    for k in (1, 2, 3):
        righe += ["## Passo %d — passo finto" % k, "", "Testo finto.", ""]
        if not (senza and k == 2):
            righe += ["Controllo: `%s` — verde (finto)" % COMANDO, ""]
    scrivi("PROPOSTA.md", "\n".join(righe))
    commit(["PROPOSTA.md"], "docs: proposta finta")
    return "Proposta scritta (finto)."


def correggi() -> str:
    """Il turno dopo la verifica: tutto buono, salvo FINTO_E03_MAI=1."""
    if os.environ.get("FINTO_E03_MAI") == "1":
        return "Non riesco a sistemare (finto)."
    for chiave in ("FINTO_E03_DOC", "FINTO_E03_PROPOSTA", "FINTO_E03_COMMIT"):
        os.environ.pop(chiave, None)
    documentazione()
    test(True)
    proposta()
    return "Sistemato (finto)."


def scena(prompt: str, sessione: str, n: int, modo: str) -> str:
    """Gli effetti della chiamata; il testo della risposta."""
    if "la verifica dello spazio di lavoro dice" in prompt.lower():
        return correggi()
    if "due subagent Explore" in prompt:
        return mappa(sessione, n)
    if "Scrivi la documentazione" in prompt:
        return documentazione()
    if "Scrivi i test di caratterizzazione" in prompt:
        return test(False)
    if "Esegui di nuovo i test" in prompt:
        return test(True)
    if "Scrivi NOTA.md" in prompt:
        return nota()
    if "Proponi il refactoring" in prompt:
        return piano(sessione, n, modo)
    if "Il piano è approvato" in prompt:
        return proposta()
    return "Risposta finta, nessun effetto."


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    n = registra(argv)
    if os.environ.get("FINTO_ESITO") == "ko" or \
            os.environ.get("FINTO_KO_ALLA") == str(n):
        return 1
    try:
        opzioni, prompt = leggi_argomenti(argv)
    except ValueError as errore:
        sys.stderr.write("%s\n" % errore)
        return 1
    formato = opzioni.get("--output-format")
    if formato not in ("json", "stream-json"):
        sys.stderr.write("error: il finto risponde in json o stream-json\n")
        return 1
    if formato == "stream-json" and "--verbose" not in opzioni:
        sys.stderr.write("error: il finto vuole --verbose con "
                         "--output-format stream-json\n")
        return 1
    sessione = opzioni.get("--resume") or "sessione-finta-%d" % n
    trascrizione(sessione, [{"type": "user", "isSidechain": False,
                             "sessionId": sessione,
                             "message": {"role": "user", "content": prompt}}])
    testo = scena(prompt, sessione, n, opzioni.get("--permission-mode", ""))
    stampa(formato, sessione, {
        "type": "result", "subtype": "success", "is_error": False,
        "duration_ms": 1000 + n, "num_turns": 3, "result": testo,
        "session_id": sessione, "total_cost_usd": 0,
        "usage": {"input_tokens": 10, "cache_creation_input_tokens": 100,
                  "cache_read_input_tokens": 1000, "output_tokens": 50}})
    return 0


def stampa(formato: str, sessione: str, primo: dict) -> None:
    """La risposta: il JSON di --output-format json, oppure lo stream di
    stream-json, un evento per riga; con i subagent in background due
    risultati, il secondo dopo la loro notifica."""
    if formato == "json":
        print(json.dumps(primo, ensure_ascii=False))
        return
    eventi = [{"type": "system", "subtype": "init", "session_id": sessione},
              {"type": "assistant", "session_id": sessione,
               "message": {"role": "assistant", "content": [
                   {"type": "text", "text": primo["result"]}]}},
              dict(primo, result_index=0)]
    if SUBAGENTI:
        eventi += [{"type": "user", "session_id": sessione,
                    "message": {"role": "user", "content":
                                "<task-notification>(finta)"
                                "</task-notification>"}},
                   dict(primo, num_turns=2, duration_ms=500, result_index=1,
                        origin={"kind": "task-notification"},
                        usage={"input_tokens": 5,
                               "cache_creation_input_tokens": 50,
                               "cache_read_input_tokens": 500,
                               "output_tokens": 25})]
    for evento in eventi:
        print(json.dumps(evento, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
