#!/usr/bin/env python3
"""claude_finto_m4_e01_e02.py -- un claude finto per le prove di M4-E01 e
M4-E02 (test_m4_e01.sh, test_m4_e02.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
_docente/live.sh dei due elementi girano per intero senza chiamare il
modello e senza consumare il piano. Le risposte e le trascrizioni che
scrive sono inventate e dichiarate finte: nessuna è di Claude. Gli
effetti sui file (la spiegazione, i test, il codice, i commit) li produce
il finto stesso, come li produrrebbe una sessione: provano i controlli,
non il modello.

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

Le scene, dal prompt:
  M4-E01  «spiegazione.md»   scrive spiegazione.md; FINTO_E01_SPIEGAZIONE
                             = si (default) · vuota · no
          «caso limite»      aggiunge il test; FINTO_E01_TEST = buono
                             (default: un metodo in VerificaCoperturaTest
                             con il segno FINTO-RICHIEDE del confine) ·
                             nuovo (un file nuovo) · stile (un file nuovo
                             con $this->assert) · rosso · no
          «comando che hai eseguito»  nessun effetto
  M4-E02  «Prepara un piano» il piano: nessuna modifica; se le impostazioni
                             hanno plansDirectory, vi scrive piano-finto.md
          «@agent-autore-test»  un Agent autore-test che scrive un test
                             finto (il segno FINTO-RICHIEDE del criterio
                             $dal, che il codice di partenza non ha);
                             FINTO_E02_LAVORO = completo (default: anche il
                             codice di FINTO_SOLUZIONE) · a_meta (solo il
                             test) · mai (niente); poi un commit
          «Prima del commit che chiude»  un Agent revisore e un commit
          «Scrivi NOTA.md»   NOTA.md (FINTO_NOTA=no: niente) e un commit
          «Leggi NOTA.md»    sessione nuova: completa il codice che manca
                             (salvo FINTO_E02_MAI=1), revisore, commit
          «correggi il codice finché passa»  come la ripresa
  Il revisore: FINTO_REVISORE = pulito (default: Read e Grep) · modifica
  (anche un Edit); come la sua trascrizione si lega alla chiamata:
  FINTO_META = si|no (il meta.json con agentType), FINTO_PRIMO_MESSAGGIO =
  uguale|diverso (il primo messaggio del subagent e il prompt della
  chiamata), FINTO_RISULTATO_ID = si|no (l'agentId nel risultato).
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

OPZIONI = {"-p": 0, "--print": 0, "--strict-mcp-config": 0,
           "--model": 1, "--effort": 1, "--allowedTools": 1,
           "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1,
           "--resume": 1}
PROGETTO = "progetti/gestionale-php"
TEST_COPERTURA = PROGETTO + "/tests/Integrazione/VerificaCoperturaTest.php"
TEST_NUOVO_E01 = PROGETTO + "/tests/Integrazione/CoperturaDalGiornoTest.php"
TEST_E02 = PROGETTO + "/tests/Integrazione/FiltroApparatoTest.php"
SRC_E02 = ("src/Ticket/FiltroTicket.php", "src/Ticket/TicketRepository.php")
CONFINE = "$riga['disponibile_dal'] <= $giorno"

METODO_E01 = '''
    public function testCopertoDalGiornoInCuiDiventaDisponibile(): void
    {
        // Test finto del claude finto. FINTO-RICHIEDE: %s
        $esito = self::$verifica->verifica(
            'Pergine Valsugana',
            "Via dell'Esempio",
            '12',
            '',
            new DateTimeImmutable('2014-02-03'),
        );

        self::assertTrue($esito->coperto);
    }
''' % CONFINE

FILE_E01 = '''<?php

declare(strict_types=1);

namespace CiaspoLink\\Gestionale\\Tests\\Integrazione;

use CiaspoLink\\Gestionale\\Copertura\\CoperturaRepository;
use CiaspoLink\\Gestionale\\Copertura\\VerificaCopertura;
use CiaspoLink\\Gestionale\\Offerte\\CatalogoRepository;
use CiaspoLink\\Gestionale\\Tests\\Support\\DatabaseDiProva;
use DateTimeImmutable;
use PHPUnit\\Framework\\TestCase;

final class CoperturaDalGiornoTest extends TestCase
{
    public function testCopertoDalGiornoInCuiDiventaDisponibile(): void
    {
        // Test finto del claude finto. FINTO-RICHIEDE: %s
        $pdo = DatabaseDiProva::conDati();
        $verifica = new VerificaCopertura(new CoperturaRepository($pdo), new CatalogoRepository($pdo));

        $esito = $verifica->verifica('Pergine Valsugana', "Via dell'Esempio", '12', '', new DateTimeImmutable('2014-02-03'));

        %s($esito->coperto);
    }
}
'''

FILE_E02 = '''<?php

declare(strict_types=1);

namespace CiaspoLink\\Gestionale\\Tests\\Integrazione;

use CiaspoLink\\Gestionale\\Tests\\Support\\DatabaseDiProva;
use CiaspoLink\\Gestionale\\Ticket\\FiltroTicket;
use CiaspoLink\\Gestionale\\Ticket\\TicketRepository;
use PHPUnit\\Framework\\TestCase;

final class FiltroApparatoTest extends TestCase
{
    public function testFiltraPerApparato(): void
    {
        // Test finto del claude finto. FINTO-RICHIEDE: ?DateTimeImmutable $dal
        $ticket = new TicketRepository(DatabaseDiProva::conDati());

        self::assertNotEmpty($ticket->cerca(new FiltroTicket(apparatoId: 'olt-pergine-01')));
    }
}
'''


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt dopo «--»)."""
    opzioni = {}  # type: Dict[str, str]
    i = 0
    while i < len(argv) and argv[i] != "--":
        parola = argv[i]
        if parola not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % parola)
        if i + OPZIONI[parola] >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % parola)
        opzioni[parola] = argv[i + 1] if OPZIONI[parola] else ""
        i += 1 + OPZIONI[parola]
    if i + 2 != len(argv):
        raise Rifiutato("error: il finto vuole «--» e un solo prompt")
    if opzioni.get("--output-format") != "json":
        raise Rifiutato("error: il finto vuole --output-format json")
    return opzioni, argv[i + 1]


def registra(argv: List[str]) -> int:
    """Una riga in FINTO_LOG; restituisce il numero della chiamata."""
    log = os.environ["FINTO_LOG"]
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({
            "argv": argv, "cwd": os.getcwd(),
            "chiave": bool(os.environ.get("ANTHROPIC_API_KEY"))},
            ensure_ascii=False) + "\n")
    with open(log, encoding="utf-8") as fh:
        return sum(1 for _ in fh)


def scrivi(percorso: str, testo: str) -> None:
    """Scrive un file dello spazio di lavoro, creando le cartelle."""
    cartella = os.path.dirname(percorso)
    if cartella:
        os.makedirs(cartella, exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(testo)


def commit(messaggio: str) -> None:
    """git add -A e un commit, se c'è qualcosa da registrare."""
    subprocess.run(["git", "add", "-A"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    stato = subprocess.run(["git", "status", "--porcelain"], check=False,
                           stdout=subprocess.PIPE, universal_newlines=True)
    if stato.stdout.strip():
        subprocess.run(["git", "-c", "user.name=Claude finto", "-c",
                        "user.email=finto@example.org", "-c",
                        "commit.gpgsign=false", "commit", "-q", "-m",
                        messaggio], check=False, stdout=subprocess.DEVNULL)


class Trascrizione:
    """Le trascrizioni finte di una sessione, se c'è PN_CLAUDE_DIR."""

    def __init__(self, sessione: str, numero: int) -> None:
        base = os.environ.get("PN_CLAUDE_DIR")
        self.cartella = None  # type: Optional[str]
        if base:
            nome = re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(os.getcwd()))
            self.cartella = os.path.join(base, "projects", nome)
            os.makedirs(self.cartella, exist_ok=True)
        self.sessione = sessione
        self.numero = numero
        self.conta = 0

    def _id(self, prefisso: str) -> str:
        self.conta += 1
        return "%s%03d%03d" % (prefisso, self.numero, self.conta)

    def riga(self, oggetto: dict, file: Optional[str] = None) -> None:
        """Aggiunge una riga JSON alla sessione o al file dato."""
        if self.cartella is None:
            return
        destinazione = file or os.path.join(self.cartella,
                                            self.sessione + ".jsonl")
        oggetto.setdefault("sessionId", self.sessione)
        oggetto.setdefault("cwd", os.getcwd())
        with open(destinazione, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(oggetto, ensure_ascii=False) + "\n")

    def messaggio(self, ruolo: str, contenuto, extra=None) -> None:
        """Un messaggio della conversazione principale."""
        oggetto = {"type": ruolo, "uuid": self._id("u"),
                   "message": {"role": ruolo, "content": contenuto}}
        if ruolo == "assistant":
            oggetto["message"]["id"] = self._id("msg_finto_")
        oggetto.update(extra or {})
        self.riga(oggetto)

    def subagent(self, tipo: str, prompt: str, strumenti: List[str]) -> None:
        """Una chiamata Agent con la trascrizione del subagent."""
        uso = self._id("toolu_finto_")
        agente = "a%013d" % (self.numero * 1000 + self.conta)
        self.messaggio("assistant", [{
            "type": "tool_use", "id": uso, "name": "Agent",
            "input": {"description": "lavoro finto di %s" % tipo,
                      "prompt": prompt, "subagent_type": tipo}}])
        testo = "Fatto (finto)."
        if os.environ.get("FINTO_RISULTATO_ID", "si") == "si":
            testo += " agentId: %s" % agente
        self.messaggio("user", [{"type": "tool_result", "tool_use_id": uso,
                                 "content": [{"type": "text",
                                              "text": testo}]}])
        if self.cartella is None:
            return
        cartella = os.path.join(self.cartella, self.sessione, "subagents")
        os.makedirs(cartella, exist_ok=True)
        file = os.path.join(cartella, "agent-%s.jsonl" % agente)
        primo = prompt
        if os.environ.get("FINTO_PRIMO_MESSAGGIO", "uguale") != "uguale":
            primo = "Un compito finto, scritto con altre parole."
        self.riga({"type": "user", "isSidechain": True, "agentId": agente,
                   "uuid": self._id("u"),
                   "message": {"role": "user", "content": primo}}, file)
        for nome in strumenti:
            self.riga({"type": "assistant", "isSidechain": True,
                       "agentId": agente, "uuid": self._id("u"),
                       "message": {"role": "assistant",
                                   "id": self._id("msg_finto_"),
                                   "content": [{
                                       "type": "tool_use",
                                       "id": self._id("toolu_finto_"),
                                       "name": nome,
                                       "input": {"file_path": "finto"}}]}},
                      file)
        if os.environ.get("FINTO_META", "si") == "si":
            with open(os.path.join(cartella, "agent-%s.meta.json" % agente),
                      "w", encoding="utf-8") as fh:
                json.dump({"agentType": tipo,
                           "description": "lavoro finto di %s" % tipo}, fh)


def e01_test() -> None:
    """Il test del caso limite, secondo FINTO_E01_TEST."""
    modo = os.environ.get("FINTO_E01_TEST", "buono")
    if modo == "buono":
        with open(TEST_COPERTURA, encoding="utf-8") as fh:
            testo = fh.read()
        fine = testo.rstrip().rfind("}")
        testo = testo[:fine].rstrip("\n") + "\n" + METODO_E01 + "}\n"
        with open(TEST_COPERTURA, "w", encoding="utf-8") as fh:
            fh.write(testo)
    elif modo == "nuovo":
        scrivi(TEST_NUOVO_E01, FILE_E01 % (CONFINE, "self::assertTrue"))
    elif modo == "stile":
        scrivi(TEST_NUOVO_E01, FILE_E01 % (CONFINE, "$this->assertTrue"))
    elif modo == "rosso":
        scrivi(TEST_NUOVO_E01, FILE_E01.replace(
            "// Test finto", "// FINTO: rosso. Test finto") % (
                CONFINE, "self::assertTrue"))


def plans_directory() -> Optional[str]:
    """plansDirectory delle impostazioni dello spazio di lavoro."""
    try:
        with open(os.path.join(".claude", "settings.json"),
                  encoding="utf-8") as fh:
            valore = json.load(fh).get("plansDirectory")
    except (OSError, ValueError):
        return None
    return valore if isinstance(valore, str) and valore else None


def codice_e02() -> None:
    """Il codice di riferimento di M4-E02, da FINTO_SOLUZIONE."""
    sorgente = os.path.join(os.environ["FINTO_SOLUZIONE"], PROGETTO)
    for parte in SRC_E02:
        shutil.copyfile(os.path.join(sorgente, parte),
                        os.path.join(PROGETTO, parte))


def codice_mancante() -> bool:
    """Vero se FiltroTicket non ha ancora il filtro per apparato."""
    with open(os.path.join(PROGETTO, SRC_E02[0]), encoding="utf-8") as fh:
        return "$apparatoId" not in fh.read()


def revisore(tr: Trascrizione) -> None:
    """Una chiamata al revisore, pulita o con un Edit."""
    strumenti = ["Read", "Grep"]
    if os.environ.get("FINTO_REVISORE", "pulito") == "modifica":
        strumenti.append("Edit")
    tr.subagent("revisore", "Confronta questo diff con SPECIFICA.md "
                "(diff finto).", strumenti)


def scena(prompt: str, opzioni: Dict[str, str], tr: Trascrizione) -> str:
    """Esegue la scena del prompt; restituisce il testo della risposta."""
    if "spiegazione.md" in prompt and "VerificaCopertura" in prompt:
        modo = os.environ.get("FINTO_E01_SPIEGAZIONE", "si")
        if modo != "no":
            scrivi("spiegazione.md", "" if modo == "vuota" else
                   "Spiegazione finta del claude finto.\n"
                   "Seconda riga finta.\n")
        return "Spiegazione scritta (finto)."
    if "caso limite" in prompt:
        e01_test()
        return "Test aggiunto ed eseguito (finto)."
    if "comando che hai eseguito" in prompt:
        return "Comando (finto): tools/php.sh … Output (finto): OK."
    if "Prepara un piano" in prompt:
        cartella = plans_directory()
        if opzioni.get("--permission-mode") == "plan" and cartella:
            scrivi(os.path.join(cartella, "piano-finto.md"),
                   "# Piano finto\n")
        return "Piano finto: R1, R2, R3, R4, R5, R6."
    if "@agent-autore-test" in prompt:
        modo = os.environ.get("FINTO_E02_LAVORO", "completo")
        if modo != "mai":
            tr.subagent("autore-test", "Scrivi i test di SPECIFICA.md "
                        "(finto).", ["Read", "Write"])
            scrivi(TEST_E02, FILE_E02)
        if modo == "completo":
            codice_e02()
        commit("feat(ticket): filtro per apparato e date (finto)")
        return "Lavoro finto."
    if "Prima del commit che chiude" in prompt:
        revisore(tr)
        commit("feat(ticket): ritocchi dopo la revisione (finto)")
        return "Revisione finta."
    if "Scrivi NOTA.md" in prompt:
        if os.environ.get("FINTO_NOTA", "si") != "no":
            scrivi("NOTA.md", "# Nota finta\n\nFatto: R1 (finto).\n")
        commit("docs: la nota della prima parte (finto)")
        return "Nota scritta (finto)."
    if "Leggi NOTA.md" in prompt or "correggi il codice finché passa" \
            in prompt:
        if os.environ.get("FINTO_E02_MAI") != "1" and codice_mancante():
            codice_e02()
        revisore(tr)
        commit("feat(ticket): completa il filtro (finto)")
        return "Ripresa finta."
    return "Prompt che il finto non conosce."


def risposta(sessione: str, testo: str) -> dict:
    """Il JSON di claude -p --output-format json, finto."""
    return {"type": "result", "subtype": "success", "is_error": False,
            "session_id": sessione, "result": testo, "num_turns": 4,
            "duration_ms": 2500,
            "usage": {"input_tokens": 10,
                      "cache_creation_input_tokens": 2000,
                      "cache_read_input_tokens": 500,
                      "output_tokens": 300}}


def main(argv: List[str]) -> int:
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    numero = registra(argv)
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    if os.environ.get("FINTO_ESITO", "ok") != "ok" or \
            os.environ.get("FINTO_KO_ALLA") == str(numero):
        return 1
    sessione = opzioni.get("--resume") or "sessione-finta-%d" % numero
    tr = Trascrizione(sessione, numero)
    tr.messaggio("user", prompt)
    testo = scena(prompt, opzioni, tr)
    tr.messaggio("assistant", [{"type": "text", "text": testo}])
    print(json.dumps(risposta(sessione, testo), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
