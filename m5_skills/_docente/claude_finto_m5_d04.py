#!/usr/bin/env python3
"""claude_finto_m5_d04.py -- un claude finto per le prove di M5-D04
(test_m5_d04.sh).

La suite lo copia, con il nome «claude», davanti nel PATH: così in_classe.sh
e _docente/live.sh girano per intero senza chiamare il modello e senza
consumare il piano. Gli stream che scrive sono inventati e dichiarati finti:
nessuno è una risposta di Claude e nessuno va in soluzione/. Hanno la forma
degli stream di `claude -p --output-format stream-json --verbose` (l'evento
system/init, i messaggi assistant e user, il risultato): provano il controllo,
non il modello.

Gli argomenti: le opzioni che usa M5-D04 (OPZIONI, con quanti valori
prendono), poi il prompt, dopo «--». Rifiuta («error: …», uscita 1) un'opzione
che non conosce, un --output-format diverso da stream-json e lo stream-json
senza --verbose; --version risponde e basta.

Che cosa vede, dalla cartella corrente:
  - le skill di .claude/skills/<nome>/SKILL.md, più alcune integrate
    (INTEGRATE): vanno nell'elenco «skills» di system/init, tranne quelle che
    --settings imposta a off in skillOverrides;
  - la scena dal prompt: revisione-pr («pull request»), risposta-assistenza
    («Rispondi a questo cliente»), audit-configurazione («core-trento-01»); un
    prompt che non conosce esce 1;
  - il braccio, dai due fatti di sopra: «on» con la skill nella cartella;
    «off» con la skill nella cartella e spenta da --settings; «senza» con la
    cartella della skill che non c'è.
On: chiama la skill (tool_use Skill, poi «Launching skill» e il messaggio «Base
directory for this skill:») e legge un file sotto .claude/skills/. Una skill
con allowed-tools o disallowed-tools nel frontmatter, senza Skill(<nome>) fra
gli strumenti consentiti, finisce in permission_denials, come fa Claude Code.
Off e senza: nella revisione chiama la skill integrata code-review.

Le variabili:
  FINTO_LOG=f            aggiunge a f una riga JSON per invocazione: argv, cwd,
                         chiave (ANTHROPIC_API_KEY nell'ambiente),
                         risposte_vicine (le risposte nella cartella sopra),
                         skill, evals, progetti, ramo, diff
  FINTO_TESTO_ON, FINTO_TESTO_SENZA, FINTO_TESTO_OFF
                         il testo finale della risposta nei tre bracci
  FINTO_NON_CHIAMA=1     on, non la chiama
  FINTO_ON_RESPINTA=1    on, la chiamata è respinta dallo strumento
  FINTO_SENZA_CHIAMA=1   senza, una chiamata alla skill che riesce
  FINTO_SENZA_ELENCA=1   senza, la skill nell'elenco
  FINTO_OFF_CHIAMA=1     off, una chiamata alla skill che riesce
  FINTO_OFF_ELENCA=1     off, resta nell'elenco
  FINTO_OFF_TENTA=1      off, la tenta, e lo strumento la respinge con il testo
                         della prima esecuzione vera (RESPINTA)
  FINTO_OFF_LEGGE=1      off, legge SKILL.md da .claude/skills/ e ne esegue lo
                         script con Bash
  FINTO_NIENTE_REVIEW=1  off e senza, niente code-review
  FINTO_REVIEW_NEGATA=1  off e senza, code-review negata dal permesso
  FINTO_SENZA_ELENCO=1   l'evento init senza l'elenco «skills»
  FINTO_TRONCO=1         niente risultato finale
  FINTO_ERRORE=1         il risultato è un errore
  FINTO_SCRIVE=1         lascia un file nella cartella corrente
  FINTO_ESITO=ko         esce 1 senza stampare nulla
  FINTO_KO_SE=t          esce 1 senza stampare nulla se t è fra gli argomenti
  FINTO_KO_SENZA=1       esce 1 senza stampare nulla nel braccio senza
Uscita: 0 lo stream · 1 un argomento rifiutato, un prompt sconosciuto, un
        fallimento chiesto dalle variabili
"""
import json
import os
import re
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--allowedTools": 1, "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1, "--settings": 1}
INTEGRATE = ["code-review", "verify", "debug", "simplify"]
SESSIONE = "sessione-finta"
SCENE = (("pull request", "revisione-pr"),
         ("Rispondi a questo cliente", "risposta-assistenza"),
         ("core-trento-01", "audit-configurazione"))
RIGHE_REVISIONE = ("2.2", "4.1", "4.3", "5.1", "6.2", "7.1", "7.3", "10.2",
                   "3.5")
TESTO_ON = {
    "revisione-pr": "| regola | file | riga | che cosa non va |\n|---|---|---|"
                    "---|\n" + "\n".join(
                        "| %s | src/Report/ReportMorosita.php | 1 | testo "
                        "finto |" % n for n in RIGHE_REVISIONE)
                    + "\n\nEsito: da modificare",
    "risposta-assistenza":
        "Mi dispiace: con la sala piena è un problema vero.\nControllo subito"
        " se c'è un guasto nella vostra zona: mi scrive il codice cliente?\n"
        "Non serve riavviare nulla adesso.",
    "audit-configurazione":
        "| apparato | file | riga | categoria | gravità | descrizione |\n"
        "|---|---|---|---|---|---|\n"
        "| core-trento-01 | c.cfg | 1 | AUD-01 | alta | testo finto |\n"
        "| core-trento-01 | c.cfg | 2 | AUD-02 | alta | testo finto |\n"
        "| core-trento-01 | c.cfg | 3 | AUD-03 | alta | testo finto |\n"
        "| core-trento-01 | c.cfg | 4 | AUD-12 | bassa | testo finto |\n"
        "| core-trento-01 | c.cfg | 5 | AUD-16 | bassa | testo finto |",
}
RESPINTA = ("<tool_use_error>Skill %s is disabled for model invocation in "
            "skillOverrides settings</tool_use_error>")
TESTO_SENZA = {
    "revisione-pr": "Testo finto: una revisione generica, con l'SQL "
                    "concatenato alla riga 12 e nessun numero di regola.",
    "risposta-assistenza":
        "**Per continuare a lavorare**\n1. Prima cosa da fare.\n2. Seconda "
        "cosa da fare.\nLe faremo sapere a breve del suo ticket!!\nUn'altra "
        "frase.\nE un'altra ancora.",
    "audit-configurazione": "Testo finto: la community public è attiva e il "
                            "telnet è ammesso, in un discorso senza tabella.",
}
USO_ON = {"input_tokens": 10, "cache_creation_input_tokens": 1000,
          "cache_read_input_tokens": 5000, "output_tokens": 200}
USO_OFF = {"input_tokens": 5, "cache_creation_input_tokens": 900,
           "cache_read_input_tokens": 4000, "output_tokens": 100}


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt) degli argomenti."""
    opzioni: Dict[str, str] = {}
    i = 0
    while i < len(argv) and argv[i] != "--":
        parola = argv[i]
        if parola not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % parola)
        valori = OPZIONI[parola]
        if i + valori >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % parola)
        opzioni[parola] = argv[i + 1] if valori else ""
        i += 1 + valori
    if i >= len(argv) - 1:
        raise Rifiutato("error: missing prompt after --")
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il finto scrive solo stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def skill_su_disco() -> List[str]:
    """Le skill della cartella corrente."""
    base = os.path.join(".claude", "skills")
    if not os.path.isdir(base):
        return []
    return sorted(nome for nome in os.listdir(base) if os.path.isfile(
        os.path.join(base, nome, "SKILL.md")))


def spente(opzioni: Dict[str, str]) -> List[str]:
    """Le skill che --settings imposta a off."""
    if "--settings" not in opzioni:
        return []
    voci = json.loads(opzioni["--settings"]).get("skillOverrides", {})
    return [nome for nome, stato in voci.items() if stato == "off"]


def ha_restrizioni(skill: str) -> bool:
    """Vero se il frontmatter della skill ha allowed-tools o disallowed-tools:
    in dontAsk la chiamata serve allora la regola Skill(<nome>)."""
    percorso = os.path.join(".claude", "skills", skill, "SKILL.md")
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read()
    except OSError:
        return False
    cornice = testo.split("---")[1] if testo.count("---") >= 2 else ""
    return re.search(r"(?m)^(?:allowed-tools|disallowed-tools):",
                     cornice) is not None


def comando(*args: str) -> str:
    """L'uscita di git nella cartella corrente, "" se non riesce."""
    uscita = subprocess.run(("git",) + args, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, check=False)
    return uscita.stdout.decode("utf-8", "replace").strip()


def registra(argv: List[str]) -> None:
    """Una riga JSON in FINTO_LOG, se c'è."""
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    skill = skill_su_disco()
    riga = {"argv": argv, "cwd": os.getcwd(),
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "risposte_vicine": any(os.path.exists(os.path.join("..", nome))
                                   for nome in ("risposte",
                                                "risposte-modelli")),
            "skill": skill,
            "evals": any(os.path.exists(os.path.join(
                ".claude", "skills", nome, "evals")) for nome in skill),
            "progetti": sorted(os.listdir("progetti"))
                        if os.path.isdir("progetti") else [],
            "ramo": comando("rev-parse", "--abbrev-ref", "HEAD"),
            "diff": comando("diff", "--name-only", "main...HEAD")}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


def scena(prompt: str) -> Optional[str]:
    """La skill della scena del prompt."""
    for parola, skill in SCENE:
        if parola in prompt:
            return skill
    return None


def assistente(blocchi: List[dict], uso: dict, modello: str) -> dict:
    return {"type": "assistant", "parent_tool_use_id": None,
            "session_id": SESSIONE,
            "message": {"role": "assistant", "model": modello,
                        "content": blocchi, "usage": uso}}


def utente(blocchi: List[dict]) -> dict:
    return {"type": "user", "parent_tool_use_id": None,
            "session_id": SESSIONE,
            "message": {"role": "user", "content": blocchi}}


def chiama(nome: str, ident: str, uso: dict, modello: str) -> List[dict]:
    """Gli eventi di una chiamata Skill riuscita."""
    uso_skill = {"name": "Skill", "id": ident, "type": "tool_use",
                 "input": {"skill": nome}}
    base = ("Base directory for this skill: %s/.claude/skills/%s\n\n"
            "Corpo finto.")
    return [assistente([uso_skill], uso, modello),
            utente([{"type": "tool_result", "tool_use_id": ident,
                     "content": "Launching skill: %s" % nome}]),
            utente([{"type": "text", "text": base % (os.getcwd(), nome)}])]


def nega(nome: str, ident: str, uso: dict, modello: str) -> List[dict]:
    """Gli eventi di una chiamata Skill negata dal permesso."""
    uso_skill = {"name": "Skill", "id": ident, "type": "tool_use",
                 "input": {"skill": nome}}
    return [assistente([uso_skill], uso, modello),
            utente([{"type": "tool_result", "tool_use_id": ident,
                     "is_error": True, "content": "Permission denied."}])]


def respinge(nome: str, ident: str, uso: dict, modello: str) -> List[dict]:
    """Gli eventi di una chiamata Skill che lo strumento respinge."""
    uso_skill = {"name": "Skill", "id": ident, "type": "tool_use",
                 "input": {"skill": nome, "args": "core-trento-01"}}
    return [assistente([uso_skill], uso, modello),
            utente([{"type": "tool_result", "tool_use_id": ident,
                     "is_error": True, "content": RESPINTA % nome}])]


def strumento(nome: str, ident: str, ingresso: dict, uso: dict,
              modello: str) -> dict:
    """Un messaggio con un tool_use di un altro strumento."""
    return assistente([{"name": nome, "id": ident, "type": "tool_use",
                        "input": ingresso}], uso, modello)


def legge_la_skill(skill: str, uso: dict, modello: str) -> List[dict]:
    """Letture e script sotto .claude/skills/, senza chiamare la skill."""
    base = "%s/.claude/skills/%s" % (os.getcwd(), skill)
    comando_script = ("python3 .claude/skills/%s/scripts/controlli_ovvi.py "
                      "progetti/rete core-trento-01" % skill)
    return [strumento("Read", "toolu_finto_read",
                      {"file_path": base + "/SKILL.md"}, uso, modello),
            strumento("Bash", "toolu_finto_bash", {"command": comando_script},
                      uso, modello)]


def la_integrata(skill: str, uso: dict,
                 modello: str) -> Tuple[List[dict], List[dict]]:
    """Off e senza: nella revisione, la skill integrata code-review."""
    if skill != "revisione-pr" or acceso("FINTO_NIENTE_REVIEW"):
        return [], []
    if acceso("FINTO_REVIEW_NEGATA"):
        negate = [{"tool_name": "Skill", "tool_use_id": "toolu_finto_review",
                   "tool_input": {"skill": "code-review"}}]
        return nega("code-review", "toolu_finto_review", uso, modello), negate
    return chiama("code-review", "toolu_finto_review", uso, modello), []


def chiamate_on(skill: str, consentiti: str, uso: dict,
                modello: str) -> Tuple[List[dict], List[dict]]:
    """Il braccio on: la chiamata e una lettura sotto .claude/skills/."""
    if acceso("FINTO_NON_CHIAMA"):
        return [], []
    if acceso("FINTO_ON_RESPINTA"):
        return respinge(skill, "toolu_finto_skill", uso, modello), []
    regola = "Skill(%s)" % skill
    if ha_restrizioni(skill) and regola not in consentiti.split(","):
        negate = [{"tool_name": "Skill", "tool_use_id": "toolu_finto_skill",
                   "tool_input": {"skill": skill}}]
        return nega(skill, "toolu_finto_skill", uso, modello), negate
    lettura = strumento(
        "Read", "toolu_finto_read",
        {"file_path": "%s/.claude/skills/%s/references/guida.md"
                      % (os.getcwd(), skill)}, uso, modello)
    return chiama(skill, "toolu_finto_skill", uso, modello) + [lettura], []


def chiamate_off(skill: str, uso: dict,
                 modello: str) -> Tuple[List[dict], List[dict]]:
    """Il braccio off: la skill spenta, con i suoi file nella cartella."""
    eventi, negate = la_integrata(skill, uso, modello)
    if acceso("FINTO_OFF_CHIAMA"):
        eventi = chiama(skill, "toolu_finto_skill", uso, modello) + eventi
    if acceso("FINTO_OFF_TENTA"):
        eventi = respinge(skill, "toolu_finto_skill", uso, modello) + eventi
    if acceso("FINTO_OFF_LEGGE"):
        eventi = eventi + legge_la_skill(skill, uso, modello)
    return eventi, negate


def chiamate_senza(skill: str, uso: dict,
                   modello: str) -> Tuple[List[dict], List[dict]]:
    """Il braccio senza: la cartella della skill non c'è."""
    eventi, negate = la_integrata(skill, uso, modello)
    if acceso("FINTO_SENZA_CHIAMA"):
        eventi = chiama(skill, "toolu_finto_skill", uso, modello) + eventi
    return eventi, negate


def braccio_di(skill: str, opzioni: Dict[str, str]) -> str:
    """Il braccio di questa chiamata, da ciò che c'è nella cartella."""
    if skill not in skill_su_disco():
        return "senza"
    return "off" if skill in spente(opzioni) else "on"


def risultato(testo: str, uso: dict, turni: int, durata: int,
              negate: List[dict]) -> dict:
    return {"type": "result", "subtype": "success",
            "is_error": acceso("FINTO_ERRORE"), "num_turns": turni,
            "duration_ms": durata, "session_id": SESSIONE, "usage": uso,
            "permission_denials": negate, "result": testo}


def stream(prompt: str, opzioni: Dict[str, str]) -> List[dict]:
    """Gli eventi della chiamata; [] se il prompt è sconosciuto."""
    skill = scena(prompt)
    if skill is None:
        return []
    braccio = braccio_di(skill, opzioni)
    elenco = [n for n in skill_su_disco() if n not in spente(opzioni)]
    if (braccio == "off" and acceso("FINTO_OFF_ELENCA")) \
            or (braccio == "senza" and acceso("FINTO_SENZA_ELENCA")):
        elenco.append(skill)
    modello = opzioni.get("--model", "sonnet")
    init = {"type": "system", "subtype": "init", "cwd": os.getcwd(),
            "session_id": SESSIONE, "model": modello,
            "permissionMode": opzioni.get("--permission-mode", ""),
            "tools": ["Bash", "Read", "Skill"]}
    if not acceso("FINTO_SENZA_ELENCO"):
        init["skills"] = elenco + INTEGRATE
    uso = USO_ON if braccio == "on" else USO_OFF
    if braccio == "on":
        chiamate_skill, negate = chiamate_on(
            skill, opzioni.get("--allowedTools", ""), uso, modello)
        testo = os.environ.get("FINTO_TESTO_ON", TESTO_ON[skill])
    elif braccio == "off":
        chiamate_skill, negate = chiamate_off(skill, uso, modello)
        testo = os.environ.get("FINTO_TESTO_OFF", TESTO_SENZA[skill])
    else:
        chiamate_skill, negate = chiamate_senza(skill, uso, modello)
        testo = os.environ.get("FINTO_TESTO_SENZA", TESTO_SENZA[skill])
    eventi = [init] + chiamate_skill + [assistente(
        [{"type": "text", "text": testo}], uso, modello)]
    if not acceso("FINTO_TRONCO"):
        turni, durata = (4, 7300) if braccio == "on" else (3, 35500)
        eventi.append(risultato(testo, uso, turni, durata, negate))
    return eventi


def principale(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("2.1.317 (Claude Code, finto)")
        return 0
    registra(argv)
    if os.environ.get("FINTO_ESITO") == "ko":
        return 1
    bersaglio = os.environ.get("FINTO_KO_SE")
    if bersaglio and any(bersaglio in parola for parola in argv):
        return 1
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(exc, file=sys.stderr)
        return 1
    skill = scena(prompt)
    if skill and acceso("FINTO_KO_SENZA") \
            and braccio_di(skill, opzioni) == "senza":
        return 1
    eventi = stream(prompt, opzioni)
    if not eventi:
        print("error: un prompt che il finto non conosce", file=sys.stderr)
        return 1
    if acceso("FINTO_SCRIVE"):
        with open("segno-del-finto.txt", "w", encoding="utf-8") as fh:
            fh.write("il finto è passato di qui\n")
    for evento in eventi:
        print(json.dumps(evento, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(principale(sys.argv[1:]))
