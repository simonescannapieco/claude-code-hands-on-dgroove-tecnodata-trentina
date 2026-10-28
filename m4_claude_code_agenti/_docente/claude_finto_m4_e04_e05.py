#!/usr/bin/env python3
"""claude_finto_m4_e04_e05.py -- un claude finto per le prove di M4-E04 e
M4-E05 (test_m4_e04.sh, test_m4_e05.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
_docente/live.sh dei due elementi girano per intero senza chiamare il
modello e senza consumare il piano. Le risposte e le trascrizioni che
scrive sono inventate e dichiarate finte: nessuna è di Claude. Gli effetti
sui file (lo script, la nota, i commit) li produce il finto stesso, come li
produrrebbe una sessione: provano i controlli, non il modello.

Gli argomenti: le opzioni di handson::claude_p e dei live.sh (OPZIONI, con
quanti valori prendono), poi «--» e il prompt. Un'opzione che non conosce
la rifiuta («error: unknown option», uscita 1), come un --output-format
diverso da json. «--version» stampa una versione finta.

Ogni invocazione aggiunge a FINTO_LOG (obbligatorio, tranne --version) una
riga JSON: argv, cwd, chiave (se ANTHROPIC_API_KEY era nell'ambiente). Il
numero della chiamata è il numero di righe del registro. Una chiamata
senza --resume apre la sessione «sessione-finta-<numero>», con --resume
continua quella data. La risposta è un JSON come quello di
`claude -p --output-format json`.

Le trascrizioni, solo se c'è PN_CLAUDE_DIR (mai in ~/.claude): la
cartella del progetto è PN_CLAUDE_DIR/projects/<percorso della cartella
corrente, ogni carattere che non è lettera o cifra cambiato in «-»>; la
sessione in <id>.jsonl, ogni subagent in <id>/subagents/agent-<agentId>
.jsonl, con il suo agent-<agentId>.meta.json.

L'elemento si riconosce dalla cartella corrente: controlla_notturno.py
(M4-E04) o controlla_rapporto.py (M4-E05). Le scene, dal prompt:
  «Prepara un piano»   il piano: nessuna modifica; se le impostazioni hanno
                       plansDirectory, vi scrive piano-finto.md
  «Il piano va bene»   lo script, secondo FINTO_LAVORO = completo (default:
                       la copia di FINTO_SOLUZIONE) · a_meta (una variante
                       che il controllo boccia) · mai (niente); poi una
                       chiamata al controllo nella trascrizione (Bash, con
                       l'ultima riga «uscita: 0» o «uscita: 1») e un commit
  «Prima del commit che chiude»  un Agent revisore e un commit
  «Scrivi NOTA.md»     NOTA.md (FINTO_NOTA=no: niente) e un commit
  «Leggi NOTA.md»      sessione nuova: completa lo script (salvo
                       FINTO_MAI=1), il controllo, il revisore, un commit
  «Esegui il controllo, da solo»  come la ripresa
  Le varianti di a_meta: M4-E04 uno script con «FINTO-VARIANTE:
  manca-una» (lo emula php_finto_m4_e04.py); M4-E05 un rapporto che
  chiama FINTO_RAPPORTO (rapporto_finto_m4_e05.py) con la variante
  fine-sbagliata sullo script di riferimento FINTO_SOLUZIONE.
  Il revisore: FINTO_REVISORE = pulito (default: Read e Grep) · modifica
  (anche un Edit); come la sua trascrizione si lega alla chiamata:
  FINTO_META = si|no (il meta.json con agentType), FINTO_PRIMO_MESSAGGIO =
  uguale|diverso (il primo messaggio del subagent e il prompt della
  chiamata), FINTO_RISULTATO_ID = si|no (l'agentId nel risultato);
  FINTO_NOME_AGENT = Agent (default) | Task (il nome di prima della 2.1.63).
  FINTO_ESITO=ko             esce 1 senza stampare nulla;
  FINTO_KO_ALLA=<n>          lo stesso, solo alla chiamata n.
Uscita: 0 risposta · 1 FINTO_ESITO=ko, FINTO_KO_ALLA o un argomento rifiutato
"""
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

# Le opzioni ammesse e quanti valori prendono.
OPZIONI = {"-p": 0, "--print": 0, "--allowedTools": 1, "--model": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--output-format": 1, "--setting-sources": 1, "--effort": 1,
           "--strict-mcp-config": 0, "--resume": 1}
SCRIPT = {"M4-E04": "progetti/gestionale-php/bin/controllo-notturno.php",
          "M4-E05": "rapporto_giornaliero.py"}
CONTROLLO = {"M4-E04": "python3 controlla_notturno.py",
             "M4-E05": "python3 controlla_rapporto.py"}
SEGNO_A_META = {"M4-E04": "FINTO-VARIANTE: manca-una",
                "M4-E05": "fine-sbagliata"}


class Rifiuto(Exception):
    """Un argomento che claude rifiuterebbe: uscita 1."""


def leggi_argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """Le opzioni e il prompt (dopo «--»)."""
    valori = {}  # type: Dict[str, str]
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            if i + 1 >= len(argv):
                raise Rifiuto("error: prompt mancante dopo --")
            return valori, argv[i + 1]
        if arg not in OPZIONI:
            raise Rifiuto("error: unknown option '%s'" % arg)
        quanti = OPZIONI[arg]
        if i + quanti >= len(argv):
            raise Rifiuto("error: option '%s' argument missing" % arg)
        valori[arg] = argv[i + 1] if quanti else ""
        i += 1 + quanti
    raise Rifiuto("error: nessun prompt dopo --")


def registra(argv: List[str]) -> int:
    """Una riga in FINTO_LOG; il numero della chiamata."""
    log = os.environ.get("FINTO_LOG")
    if not log:
        raise Rifiuto("claude finto: FINTO_LOG non è impostata")
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({"argv": argv, "cwd": os.getcwd(),
                             "chiave": "ANTHROPIC_API_KEY" in os.environ},
                            ensure_ascii=False) + "\n")
    with open(log, encoding="utf-8") as fh:
        return sum(1 for _ in fh)


def elemento() -> Optional[str]:
    """L'elemento dello spazio di lavoro corrente."""
    if os.path.isfile("controlla_notturno.py"):
        return "M4-E04"
    if os.path.isfile("controlla_rapporto.py"):
        return "M4-E05"
    return None


def git(*argomenti: str) -> None:
    """Un comando git nello spazio di lavoro, con l'autore del corso."""
    subprocess.run(["git", "-c", "user.name=Corso Claude Code", "-c",
                    "user.email=corso@example.org", "-c",
                    "commit.gpgsign=false"] + list(argomenti),
                   check=False, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)


def commit(messaggio: str) -> None:
    git("add", "-A")
    git("commit", "-q", "--no-verify", "-m", messaggio)


def scrivi_script(item: str, completo: bool) -> None:
    """Lo script dell'elemento: il riferimento, o la variante a metà."""
    destinazione = SCRIPT[item]
    os.makedirs(os.path.dirname(destinazione) or ".", exist_ok=True)
    soluzione = os.environ.get("FINTO_SOLUZIONE", "")
    if completo:
        shutil.copyfile(soluzione, destinazione)
        return
    with open(destinazione, "w", encoding="utf-8") as fh:
        if item == "M4-E04":
            fh.write("<?php\n// %s (finto)\n" % SEGNO_A_META[item])
            return
        fh.write("# FINTO: uno script a metà della suite, non di Claude\n"
                 "import subprocess\nimport sys\n"
                 "sys.exit(subprocess.call([sys.executable, '-B', %r, %r, %r]"
                 " + sys.argv[1:]))\n" % (
                     os.environ.get("FINTO_RAPPORTO", ""),
                     SEGNO_A_META[item], soluzione))


def completo(item: str) -> bool:
    """Lo script c'è ed è la copia del riferimento."""
    try:
        with open(SCRIPT[item], "rb") as a, \
                open(os.environ.get("FINTO_SOLUZIONE", ""), "rb") as b:
            return a.read() == b.read()
    except OSError:
        return False


class Trascrizione:
    """Le righe JSONL di una sessione finta, in PN_CLAUDE_DIR."""

    def __init__(self, sessione: str) -> None:
        base = os.environ.get("PN_CLAUDE_DIR")
        self.cartella = None  # type: Optional[str]
        self.sessione = sessione
        self.n = 0
        if base:
            self.cartella = os.path.join(base, "projects", re.sub(
                r"[^A-Za-z0-9]", "-", os.getcwd()))
            os.makedirs(self.cartella, exist_ok=True)

    def riga(self, oggetto: dict, file: Optional[str] = None) -> None:
        if self.cartella is None:
            return
        percorso = file or os.path.join(self.cartella,
                                        self.sessione + ".jsonl")
        os.makedirs(os.path.dirname(percorso), exist_ok=True)
        with open(percorso, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(oggetto, ensure_ascii=False) + "\n")

    def messaggio(self, ruolo: str, contenuto, laterale: bool = False,
                  file: Optional[str] = None) -> None:
        self.riga({"type": ruolo, "sessionId": self.sessione,
                   "isSidechain": laterale, "cwd": os.getcwd(),
                   "message": {"role": ruolo, "content": contenuto}}, file)

    def strumento(self, nome: str, ingresso: dict, risultato: str,
                  laterale: bool = False,
                  file: Optional[str] = None) -> str:
        self.n += 1
        ident = "toolu_finto_%s_%d" % (self.sessione[-3:], self.n)
        self.messaggio("assistant", [{"type": "tool_use", "id": ident,
                                      "name": nome, "input": ingresso}],
                       laterale, file)
        self.messaggio("user", [{"type": "tool_result", "tool_use_id": ident,
                                 "content": risultato}], laterale, file)
        return ident


def revisore(t: Trascrizione, item: str, chiamata: int) -> None:
    """Una chiamata Agent al revisore, con la sua trascrizione."""
    agente = "a%05dfinto" % chiamata
    prompt = ("Ecco il diff dal primo commit dello spazio di lavoro (finto): "
              "controlla il contratto d'uscita e i messaggi dello script con "
              "SPECIFICA.md.")
    nome = os.environ.get("FINTO_NOME_AGENT", "Agent")
    risultato = "ESITO: OK\nPROBLEMI:\n- nessuno\n(risposta finta)"
    if os.environ.get("FINTO_RISULTATO_ID", "si") == "si":
        risultato += "\nagentId: %s" % agente
    t.strumento(nome, {"subagent_type": "revisore", "description":
                       "revisione finta", "prompt": prompt}, risultato)
    if t.cartella is None:
        return
    file = os.path.join(t.cartella, t.sessione, "subagents",
                        "agent-%s.jsonl" % agente)
    primo = prompt if os.environ.get("FINTO_PRIMO_MESSAGGIO",
                                     "uguale") == "uguale" else \
        "Un altro testo, che non è il prompt della chiamata (finto)."
    t.messaggio("user", primo, True, file)
    t.strumento("Read", {"file_path": "SPECIFICA.md"}, "(finto)", True, file)
    t.strumento("Grep", {"pattern": "exit"}, "(finto)", True, file)
    if os.environ.get("FINTO_REVISORE", "pulito") == "modifica":
        t.strumento("Edit", {"file_path": SCRIPT[item]}, "(finto)", True,
                    file)
    if os.environ.get("FINTO_META", "si") == "si":
        with open(file[:-len(".jsonl")] + ".meta.json", "w",
                  encoding="utf-8") as fh:
            json.dump({"agentType": "revisore", "description":
                       "revisione finta"}, fh)


def controllo(t: Trascrizione, item: str) -> None:
    """Una chiamata al controllo nella trascrizione, con la sua uscita."""
    uscita = 0 if completo(item) else 1
    t.strumento("Bash", {"command": CONTROLLO[item]},
                "(controllo finto)\nuscita: %d" % uscita)


def piano() -> None:
    """In plan mode: niente modifiche, il piano in plansDirectory."""
    try:
        with open(".claude/settings.json", encoding="utf-8") as fh:
            cartella = json.load(fh).get("plansDirectory")
    except (OSError, ValueError):
        cartella = None
    if cartella:
        os.makedirs(cartella, exist_ok=True)
        with open(os.path.join(cartella, "piano-finto.md"), "w",
                  encoding="utf-8") as fh:
            fh.write("# Piano finto\n\nScritto dal claude finto della "
                     "suite, non da Claude.\n")


def lavoro(t: Trascrizione, item: str, prompt: str, chiamata: int) -> None:
    """Gli effetti di una chiamata, secondo il prompt."""
    modo = os.environ.get("FINTO_LAVORO", "completo")
    mai = os.environ.get("FINTO_MAI") == "1"
    if "Il piano va bene" in prompt:
        if modo != "mai":
            scrivi_script(item, modo == "completo")
            controllo(t, item)
            commit("feat(controllo): primo passo (finto)")
    elif "Prima del commit che chiude" in prompt:
        revisore(t, item, chiamata)
        commit("feat(controllo): dopo la revisione (finto)")
    elif "Scrivi NOTA.md" in prompt:
        if os.environ.get("FINTO_NOTA", "si") == "si":
            with open("NOTA.md", "w", encoding="utf-8") as fh:
                fh.write("# Nota finta\n\nScritta dal claude finto della "
                         "suite.\n")
            commit("docs: nota della prima parte (finto)")
    elif "Leggi NOTA.md" in prompt or "Esegui il controllo, da solo" in prompt:
        if not mai:
            scrivi_script(item, True)
        controllo(t, item)
        revisore(t, item, chiamata)
        commit("feat(controllo): ripresa (finto)")


def risposta(sessione: str, numero: int) -> dict:
    """Il JSON di claude -p --output-format json, finto."""
    return {"type": "result", "subtype": "success", "is_error": False,
            "duration_ms": 1000 + numero, "num_turns": 3,
            "result": "(risposta finta, non di Claude)",
            "session_id": sessione, "total_cost_usd": 0,
            "usage": {"input_tokens": 10, "cache_creation_input_tokens": 100,
                      "cache_read_input_tokens": 1000, "output_tokens": 50}}


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("2.1.312 (Claude Code, finto)")
        return 0
    try:
        numero = registra(argv)
        if argv[:1] not in (["-p"], ["--print"]):
            raise Rifiuto("claude finto: serve -p")
        valori, prompt = leggi_argomenti(argv[1:])
        if valori.get("--output-format") != "json":
            raise Rifiuto("error: --output-format diverso da json")
    except Rifiuto as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    ko = os.environ.get("FINTO_KO_ALLA")
    if os.environ.get("FINTO_ESITO") == "ko" or ko == str(numero):
        return 1
    sessione = valori.get("--resume") or "sessione-finta-%03d" % numero
    t = Trascrizione(sessione)
    t.messaggio("user", prompt)
    item = elemento()
    if valori.get("--permission-mode") == "plan":
        piano()
    elif item is not None:
        lavoro(t, item, prompt, numero)
    t.messaggio("assistant", [{"type": "text",
                               "text": "(risposta finta, non di Claude)"}])
    print(json.dumps(risposta(sessione, numero), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
