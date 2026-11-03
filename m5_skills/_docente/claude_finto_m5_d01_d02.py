#!/usr/bin/env python3
"""claude_finto_m5_d01_d02.py -- un claude finto per le prove di M5-D01 e M5-D02
(test_m5_d01.sh, test_m5_d02.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così
demo/in_classe.sh e _docente/live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Gli stream che scrive sono inventati e
dichiarati finti: nessuno è una risposta di Claude, e provano i controlli, non
il modello. Hanno la forma di quelli di `claude -p --output-format stream-json
--verbose`: system/init, assistant, user, result.

Gli argomenti: le opzioni che usano i due elementi (OPZIONI, con quanti valori
prendono), poi il prompt dopo «--». Rifiuta («error: …», uscita 1) un'opzione
che non conosce, un --output-format diverso da stream-json e lo stream-json
senza --verbose. --version stampa una versione finta.

I token della prima richiesta vengono dai file della cartella da cui parte,
così un braccio costruito male cambia il conto: BASE, più il CLAUDE.md, più il
file di --append-system-prompt-file, più PER_SKILL per ogni skill senza
disable-model-invocation; con /nome anche il corpo della skill. Con --resume il
contesto della sessione salvata, più RESUME. I file contano caratteri ×
RAPPORTO. Una sessione senza --no-session-persistence si salva in
FINTO_SESSIONI, e --resume la ritrova soltanto dalla stessa cartella.

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: argv, cwd, prompt,
chiave (ANTHROPIC_API_KEY era nell'ambiente), stdin_nullo (lo STDIN è
/dev/null), risposte_vicine (una cartella risposte/ fino a quattro livelli
sopra), stream_vicini (un *.jsonl sotto la cartella di due livelli sopra).

Le scene, dal prompt:
  /<nome> …             la skill invocata: nessun tool_use, il corpo nel conto
                        dei token. /prova-d02 risponde con il marcatore del
                        corpo; una skill che non c'è, zero turni
  Rispondi solo: ok     «ok»
  --resume              una risposta breve, nella stessa sessione
  Controlla la configurazione …
                        con la skill nell'elenco e «Da usare quando» nella
                        description, la chiamata Skill come negli stream veri
                        (tool_use, «Launching skill», il messaggio sintetico
                        «Base directory for this skill:») e il marcatore nella
                        risposta; altrimenti Read e una risposta senza marcatore
  Quante righe …        Read e una risposta senza marcatore

L'ambiente (FINTO_LOG e FINTO_SESSIONI a parte) cambia ciò che succede:
  FINTO_PRIMA=n             la prima richiesta vale n token
  FINTO_SKILL_SEMPRE=nome   una chiamata Skill su nome, a qualunque prompt
  FINTO_NON_CHIAMA=1        nessuna chiamata Skill per la description
  FINTO_RIFIUTA=errore      la chiamata Skill ha un tool_result con is_error;
                =permesso   è nei permission_denials; il corpo non arriva
  FINTO_NOME_VUOTO=1        /nome: zero turni, risultato vuoto, zero token
  FINTO_NOME_SENZA_MARCATORE=1  /nome risponde senza il marcatore
  FINTO_NOME_SINTETICO=1    /nome: il messaggio sintetico e nessun marcatore
  FINTO_SENZA_SKILL_INIT=1  l'elenco skills senza quelle della cartella
  FINTO_SENZA_INIT=1        nessun evento system/init
  FINTO_INIT_SENZA_ELENCO=1 system/init senza skills
  FINTO_SENZA_ASSISTENTE=1  nessun messaggio dell'assistente
  FINTO_SENZA_USO=1         il primo messaggio senza usage
  FINTO_CAMPO_MANCANTE=1    usage senza cache_read_input_tokens
  FINTO_ZERO=1              tutti i campi di usage a zero
  FINTO_TRONCO=1            lo stream senza il risultato
  FINTO_ERRORE=1            il risultato con is_error
  FINTO_RIGA_ROTTA=1        una riga che non è JSON
  FINTO_ESITO_KO_SE=t       esce 1 senza stampare nulla se t è nel prompt o
                            nella cartella

Uscita: 0 lo stream · 1 un argomento rifiutato, FINTO_ESITO_KO_SE, una sessione
che non c'è
"""
import glob
import json
import os
import re
import sys
import uuid
from typing import Dict, List, NamedTuple, Optional, Tuple

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--resume": 1,
           "--append-system-prompt-file": 1, "--tools": 1}
BASE = 17000
PER_SKILL = 50
RESUME = 16
RAPPORTO = 0.43
INTEGRATE = ["code-review", "debug", "verify"]
MARCATORE = re.compile(r"«(AUD-[0-9]+) riga N»")
NOTA = " (risposta del claude finto)"


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


class Skill(NamedTuple):
    """Una skill della cartella."""
    nome: str
    descrizione: str
    manuale: bool
    corpo: str


class Scena(NamedTuple):
    """Ciò che serve per scrivere uno stream."""
    cwd: str
    sessione: str
    skills: List[Skill]
    prima: int


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt)."""
    opzioni: Dict[str, str] = {}
    i = 0
    while i < len(argv) and argv[i] != "--":
        nome = argv[i]
        if nome not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % nome)
        if OPZIONI[nome] and i + 1 >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % nome)
        opzioni[nome] = argv[i + 1] if OPZIONI[nome] else ""
        i += 1 + OPZIONI[nome]
    if i >= len(argv) or len(argv) != i + 2:
        raise Rifiutato("error: il prompt va dopo «--»")
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il finto scrive soltanto stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def leggi_skill(percorso: str) -> Skill:
    """Il frontmatter e il corpo di uno SKILL.md, nella forma semplice che gli
    elementi scrivono."""
    with open(percorso, encoding="utf-8") as fh:
        testo = fh.read()
    pezzi = testo.split("---\n", 2)
    campi: Dict[str, str] = {}
    for riga in pezzi[1].splitlines():
        chiave, _, valore = riga.partition(": ")
        campi[chiave] = valore
    return Skill(campi.get("name", ""), campi.get("description", ""),
                 campi.get("disable-model-invocation") == "true",
                 pezzi[2].lstrip("\n"))


def skills_della_cartella() -> List[Skill]:
    """Le skill di .claude/skills/ della cartella corrente."""
    return [leggi_skill(p) for p in sorted(glob.glob(
        os.path.join(".claude", "skills", "*", "SKILL.md")))]


def token_di(percorso: str) -> int:
    """I token finti di un file: caratteri × RAPPORTO."""
    with open(percorso, encoding="utf-8") as fh:
        return int(len(fh.read()) * RAPPORTO)


def sessione_salvata(ident: str, cwd: str) -> Optional[dict]:
    """La sessione salvata, soltanto dalla stessa cartella."""
    cartella = os.environ.get("FINTO_SESSIONI", "")
    percorso = os.path.join(cartella, ident + ".json")
    if not cartella or not os.path.exists(percorso):
        return None
    with open(percorso, encoding="utf-8") as fh:
        dati = json.load(fh)
    return dati if dati.get("cwd") == cwd else None


def salva_sessione(ident: str, cwd: str, contesto: int) -> None:
    """Salva la sessione in FINTO_SESSIONI, se c'è."""
    cartella = os.environ.get("FINTO_SESSIONI", "")
    if cartella:
        os.makedirs(cartella, exist_ok=True)
        with open(os.path.join(cartella, ident + ".json"), "w",
                  encoding="utf-8") as fh:
            json.dump({"cwd": cwd, "contesto": contesto}, fh)


def prima_richiesta(opzioni: Dict[str, str], prompt: str,
                    skills: List[Skill], salvata: Optional[dict]) -> int:
    """I token della prima richiesta, dai file della cartella."""
    if os.environ.get("FINTO_PRIMA"):
        return int(os.environ["FINTO_PRIMA"])
    if salvata is not None:
        return int(salvata["contesto"]) + RESUME
    totale = BASE
    if os.path.exists("CLAUDE.md"):
        totale += token_di("CLAUDE.md")
    if opzioni.get("--append-system-prompt-file"):
        totale += token_di(opzioni["--append-system-prompt-file"])
    totale += PER_SKILL * sum(1 for s in skills if not s.manuale)
    for skill in skills:
        if prompt.startswith("/" + skill.nome):
            totale += int(len(skill.corpo) * RAPPORTO)
    return totale


def uso(totale: int) -> Dict[str, int]:
    """I campi di usage: i token stanno in tutti e tre, come negli stream
    veri, così chi ne somma uno solo sbaglia."""
    letti = min(11000, max(totale - 3, 0))
    risultato = {"input_tokens": min(3, totale),
                 "cache_creation_input_tokens": max(totale - 3 - letti, 0),
                 "cache_read_input_tokens": letti, "output_tokens": 4}
    if acceso("FINTO_CAMPO_MANCANTE"):
        del risultato["cache_read_input_tokens"]
    if acceso("FINTO_ZERO"):
        risultato = {k: 0 for k in risultato}
    return risultato


def assistente(scena: Scena, contenuto: List[dict], totale: int,
               con_uso: bool = True) -> dict:
    """Un messaggio dell'assistente della conversazione principale."""
    messaggio: Dict[str, object] = {"role": "assistant", "content": contenuto,
                                    "model": "finto"}
    if con_uso:
        messaggio["usage"] = uso(totale)
    return {"type": "assistant", "message": messaggio,
            "parent_tool_use_id": None, "session_id": scena.sessione}


def utente(scena: Scena, contenuto: List[dict],
           sintetico: bool = False) -> dict:
    """Un messaggio utente: il risultato di uno strumento, o quello sintetico
    con il corpo della skill."""
    evento = {"type": "user", "parent_tool_use_id": None,
              "message": {"role": "user", "content": contenuto},
              "session_id": scena.sessione}
    if sintetico:
        evento["isSynthetic"] = True
    return evento


def chiamata_skill(scena: Scena, nome: str) -> Tuple[List[dict], List[dict],
                                                     bool]:
    """Gli eventi di una chiamata a Skill, i dinieghi, se il corpo è arrivato.
    Il tool_use e il risultato hanno lo stesso id."""
    ident = "toolu_finto_skill"
    eventi = [assistente(scena, [{"type": "tool_use", "id": ident,
                                  "name": "Skill", "input": {"skill": nome}}],
                         scena.prima)]
    rifiuta = os.environ.get("FINTO_RIFIUTA", "")
    if rifiuta == "permesso":
        eventi.append(utente(scena, [{
            "type": "tool_result", "tool_use_id": ident, "is_error": True,
            "content": "Permission denied (finto)"}]))
        return eventi, [{"tool_name": "Skill", "tool_use_id": ident}], False
    if rifiuta == "errore":
        eventi.append(utente(scena, [{
            "type": "tool_result", "tool_use_id": ident, "is_error": True,
            "content": "<tool_use_error>rifiutata (finto)</tool_use_error>"}]))
        return eventi, [], False
    eventi.append(utente(scena, [{"type": "tool_result", "tool_use_id": ident,
                                  "content": "Launching skill: " + nome}]))
    trovate = [s for s in scena.skills if s.nome == nome]
    if not trovate:
        return eventi, [], False
    testo = "Base directory for this skill: %s/.claude/skills/%s\n\n%s" % (
        scena.cwd, nome, trovate[0].corpo)
    eventi.append(utente(scena, [{"type": "text", "text": testo}], True))
    return eventi, [], True


def risposta_marcata(skills: List[Skill]) -> str:
    """Il marcatore del corpo di prova-d02, se c'è, nella risposta finta."""
    for skill in skills:
        trovato = MARCATORE.search(skill.corpo)
        if trovato:
            return "%s riga 2%s" % (trovato.group(1), NOTA)
    return "nessun problema" + NOTA


def lettura(scena: Scena) -> List[dict]:
    """Una lettura con Read, come in una risposta senza la skill."""
    ident = "toolu_finto_read"
    return [assistente(scena, [{"type": "tool_use", "id": ident, "name": "Read",
                                "input": {"file_path": "configurazione.txt"}}],
                       scena.prima),
            utente(scena, [{"type": "tool_result", "tool_use_id": ident,
                            "content": "hostname sw-prova-01 (finto)"}])]


def invocata(scena: Scena, prompt: str) -> Tuple[List[dict], str, int]:
    """/nome: gli eventi, la risposta e i turni."""
    nome = prompt[1:].split()[0]
    trovate = [s for s in scena.skills if s.nome == nome]
    if not trovate or acceso("FINTO_NOME_VUOTO"):
        return [], "", 0
    if acceso("FINTO_NOME_SINTETICO"):
        testo = "Base directory for this skill: %s/.claude/skills/%s\n\n%s" % (
            scena.cwd, nome, trovate[0].corpo)
        return ([utente(scena, [{"type": "text", "text": testo}], True)],
                "Fatto" + NOTA, 1)
    if acceso("FINTO_NOME_SENZA_MARCATORE"):
        return [], "Fatto" + NOTA, 1
    if nome == "procedure-assistenza":
        return [], "20 Mbit/s" + NOTA, 1
    return [], risposta_marcata(trovate), 1


def naturale(scena: Scena, prompt: str) -> Tuple[List[dict], List[dict], str,
                                                 int]:
    """Una richiesta senza /nome: gli eventi, i dinieghi, la risposta, i turni.
    """
    specifica = [s for s in scena.skills
                 if not s.manuale and "Da usare quando" in s.descrizione]
    if prompt.startswith("Controlla la configurazione") and specifica \
            and not acceso("FINTO_NON_CHIAMA"):
        eventi, dinieghi, arrivato = chiamata_skill(scena, specifica[0].nome)
        testo = risposta_marcata(specifica) if arrivato else "Fatto" + NOTA
        return eventi, dinieghi, testo, 2
    if prompt.startswith(("Controlla la configurazione", "Quante righe")):
        return lettura(scena), [], "Due righe" + NOTA, 2
    return [], [], "ok" if prompt == "Rispondi solo: ok" else "Una risposta" \
        + NOTA, 1


def forzata(scena: Scena, nome: str) -> Tuple[List[dict], List[dict], str]:
    """FINTO_SKILL_SEMPRE: la chiamata a una skill data, e la sua risposta."""
    eventi, dinieghi, arrivato = chiamata_skill(scena, nome)
    if not arrivato:
        return eventi, dinieghi, "Fatto" + NOTA
    return eventi, dinieghi, risposta_marcata(
        [s for s in scena.skills if s.nome == nome])


def elenco_init(skills: List[Skill]) -> List[str]:
    """L'elenco skills di system/init: quelle della cartella, poi le integrate.
    """
    if acceso("FINTO_SENZA_SKILL_INIT"):
        return list(INTEGRATE)
    return [s.nome for s in skills] + list(INTEGRATE)


def eventi_della_scena(scena: Scena, opzioni: Dict[str, str],
                       prompt: str) -> Tuple[List[dict], List[dict], str, int]:
    """Gli eventi fra system/init e il risultato."""
    forza = os.environ.get("FINTO_SKILL_SEMPRE")
    if forza:
        eventi, dinieghi, testo = forzata(scena, forza)
        return eventi, dinieghi, testo, 2
    if prompt.startswith("/"):
        eventi, testo, turni = invocata(scena, prompt)
        return eventi, [], testo, turni
    if "--resume" in opzioni:
        return [], [], "100 Mbit/s" + NOTA, 1
    return naturale(scena, prompt)


def costruisci(scena: Scena, opzioni: Dict[str, str],
               prompt: str) -> List[dict]:
    """Tutto lo stream, come lista di eventi."""
    eventi, dinieghi, testo, turni = eventi_della_scena(scena, opzioni, prompt)
    vuoto = prompt.startswith("/") and turni == 0
    finale = assistente(scena, [{"type": "text", "text": testo}],
                        0 if vuoto else scena.prima + 100 * len(eventi))
    corpo = eventi + [finale]
    if acceso("FINTO_SENZA_ASSISTENTE"):
        corpo = []
    if acceso("FINTO_SENZA_USO"):
        corpo = [assistente(scena, [{"type": "text", "text": testo}], 0, False)]
    errore = acceso("FINTO_ERRORE")
    risultato = {"type": "result", "subtype": "success", "is_error": errore,
                 "result": testo, "session_id": scena.sessione,
                 "num_turns": turni, "permission_denials": dinieghi}
    inizio: List[dict] = []
    if not acceso("FINTO_SENZA_INIT"):
        init = {"type": "system", "subtype": "init", "cwd": scena.cwd,
                "session_id": scena.sessione, "model": "finto",
                "claude_code_version": "finto"}
        if not acceso("FINTO_INIT_SENZA_ELENCO"):
            init["skills"] = elenco_init(scena.skills)
        inizio = [init]
    coda = [] if acceso("FINTO_TRONCO") else [risultato]
    return inizio + corpo + coda


def registra(opzioni_argv: List[str], prompt: str) -> None:
    """Una riga JSON in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    cwd = os.getcwd()
    sopra, vicine = cwd, False
    for _ in range(4):
        sopra = os.path.dirname(sopra)
        vicine = vicine or os.path.isdir(os.path.join(sopra, "risposte"))
    stream = False
    for cartella, _, nomi in os.walk(os.path.dirname(os.path.dirname(cwd))):
        stream = stream or any(n.endswith(".jsonl") for n in nomi)
        if stream or cartella.count(os.sep) > cwd.count(os.sep) + 2:
            break
    nullo = os.path.samestat(os.fstat(0), os.stat(os.devnull))
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({
            "argv": opzioni_argv, "cwd": cwd, "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ, "stdin_nullo": nullo,
            "risposte_vicine": vicine, "stream_vicini": stream},
            ensure_ascii=False) + "\n")


def scrivi(eventi: List[dict]) -> None:
    """Lo stream su STDOUT, una riga per evento."""
    for evento in eventi:
        sys.stdout.write(json.dumps(evento, ensure_ascii=False) + "\n")
    if acceso("FINTO_RIGA_ROTTA"):
        sys.stdout.write("questa riga non è JSON\n")


def main(argv: List[str]) -> int:
    if argv[:1] == ["--version"]:
        registra(argv, "")
        print("9.9.9 (claude finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    registra(argv, prompt)
    cwd = os.getcwd()
    ko = os.environ.get("FINTO_ESITO_KO_SE")
    if ko and (ko in prompt or ko in cwd):
        return 1
    salvata = None
    ident = str(uuid.uuid4())
    if "--resume" in opzioni:
        ident = opzioni["--resume"]
        salvata = sessione_salvata(ident, cwd)
        if salvata is None:
            print("No conversation found with session ID: %s" % ident,
                  file=sys.stderr)
            return 1
    skills = skills_della_cartella()
    prima = prima_richiesta(opzioni, prompt, skills, salvata)
    scena = Scena(cwd, ident, skills, prima)
    scrivi(costruisci(scena, opzioni, prompt))
    if "--no-session-persistence" not in opzioni:
        salva_sessione(ident, cwd, prima)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
