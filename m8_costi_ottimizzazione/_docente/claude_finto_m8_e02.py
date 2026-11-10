#!/usr/bin/env python3
"""claude_finto_m8_e02.py -- un claude finto per le prove di M8-E02
(test_m8_e02.sh).

La suite lo mette davanti nel PATH attraverso un piccolo involucro che imposta
FINTO_MODI e FINTO_LOG: così misura.sh, _docente/live.sh e la verifica girano
per intero senza chiamare il modello. Niente di ciò che scrive è una risposta
di Claude: i testi finiscono con «(risposta del claude finto)», e i JSON hanno
la forma di quelli di `claude -p --output-format json`. Provano gli script e
i controlli, non il modello.

Le chiamate che riconosce (i token sono calcolati dal testo, come fa il
listino del corso: input in cache con la durata di un'ora, poco input, i
costi ai prezzi di listino, così il costo ricalcolato coincide con
total_cost_usd):
  --version
  il giudice (ha --agent giudice): un esito per ogni affermazione del tag
      rubric della consegna, tutte rispettate salvo i modi qui sotto;
  una risposta: dal messaggio riconosce il caso e scrive una risposta che
      supera i controlli del caso. Un prompt corto (meno di SOGLIA_CORTO byte,
      cioè una versione tagliata) e una risposta di una versione corta portano
      la marca [versione corta], che il giudice finto riconosce.

Le parole di FINTO_MODI cambiano ciò che succede:
  corto-no-controlli    a un prompt corto la risposta perde la segnalazione e
                        usa «sicuramente»: due controlli in meno
  corto-no-giudice      su una risposta con la marca [versione corta] il
                        giudice nega la prima affermazione
  errore-risposta       il risultato della risposta con is_error
  errore-giudice        il risultato del giudice con is_error
  senza-structured      il giudice senza structured_output
  fuori-schema          lo structured_output con un campo in più
  usage-rotto           usage.input_tokens non è un numero
  ko-se=testo           esce 1, senza stampare nulla, se il testo è nel prompt

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
stdin_nullo.

Uscita: 0 la risposta · 1 ko-se
"""
import json
import os
import re
import stat
import sys
import uuid
from typing import Any, Dict, List, Optional

NOTA = " (risposta del claude finto)"
MARCA_CORTA = "[versione corta]"
SOGLIA_CORTO = 12000   # byte: sotto, il prompt è di una versione tagliata
RISPOSTE = {
    "caso-1": ("Buongiorno Laura,\n\nmi dispiace: la sua linea è ferma per un "
               "guasto sulla nostra rete a Pergine. I tecnici sono sul posto; "
               "non abbiamo ancora un orario di ripristino e le mandiamo un "
               "SMS appena la linea torna.\n\nLa segnalazione TK-2026-04294 è "
               "collegata al guasto. Dopo il ripristino, se il router non si "
               "ricollega da solo, lo spenga per 30 secondi e lo riaccenda."
               "\n\nIl team di assistenza CiaspoLink"),
    "caso-2": ("Buongiorno signor Campione,\n\nmi dispiace: c'è un guasto sul "
               "collegamento radio della zona di Cles e il problema non "
               "dipende dal rifugio. I tecnici sono al lavoro e una stima non "
               "c'è ancora.\n\nHo aperto la segnalazione TK-2026-04367 con "
               "priorità alta e la conversazione passa a un operatore, che ha "
               "già un riepilogo: azienda, POS e prenotazioni bloccati.\n\n"
               "Il team di assistenza CiaspoLink"),
    "caso-3": ("Ciao Mario, c'è un guasto nella zona radio di Cles: la tua "
               "antenna riceve bene, il problema non dipende da te. Lo speed "
               "test l'hai fatto bene, non serve ripeterlo. Un orario di "
               "ripristino non c'è ancora: ti avviso appena torna a posto. "
               "La segnalazione è la TK-2026-04387."),
}
RICONOSCI = {
    "da poco dopo le dieci non ho più internet": "caso-1",
    "Sono il gestore del Rifugio Campione": "caso-2",
    "lo speed test col cavo va da 3 a 40 mega": "caso-3",
}
PREZZI = {"haiku": (0.10, 0.50, 0.20, 0.01), "sonnet": (2.0, 10.0, 4.0, 0.10),
          "opus": (4.0, 20.0, 8.0, 0.20)}   # input, output, cache 1 h, cache read


def modi() -> List[str]:
    return os.environ.get("FINTO_MODI", "").split()


def valore(argv: List[str], opzione: str) -> Optional[str]:
    if opzione in argv and argv.index(opzione) + 1 < len(argv):
        return argv[argv.index(opzione) + 1]
    return None


def prompt_di(argv: List[str]) -> str:
    if "--" in argv and argv.index("--") + 1 < len(argv):
        return argv[argv.index("--") + 1]
    return ""


def stdin_nullo() -> bool:
    """Vero se lo STDIN è /dev/null."""
    try:
        dati = os.fstat(0)
        nullo = os.stat(os.devnull)
    except OSError:
        return False
    return stat.S_ISCHR(dati.st_mode) and dati.st_rdev == nullo.st_rdev


def registra(argv: List[str], prompt: str) -> None:
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    voce = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "stdin_nullo": stdin_nullo()}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(voce, ensure_ascii=False) + "\n")


def token_da(testo: str) -> int:
    """I token di un testo, come nelle chiamate vere (circa 2,35 byte per
    token), almeno 1."""
    return max(int(len(testo.encode("utf-8")) * 100 / 235), 1)


def documento(risultato: str, alias: str, entrata: int, uscita: int,
              turni: int, extra: Dict[str, Any]) -> Dict[str, Any]:
    """Il JSON di una chiamata, con i token in cache (scrittura a 1 ora) e i
    costi ai prezzi del listino."""
    p = PREZZI[alias]
    scritti = max(entrata - 2, 0)
    costo = (2 * p[0] + scritti * p[2] + uscita * p[1]) / 1000000.0
    doc: Dict[str, Any] = {
        "type": "result", "subtype": "success", "is_error": False,
        "duration_ms": 8000, "duration_api_ms": 7500, "num_turns": turni,
        "result": risultato, "stop_reason": "end_turn",
        "session_id": "sess-" + uuid.uuid4().hex[:8],
        "total_cost_usd": costo,
        "usage": {"input_tokens": 2, "cache_creation_input_tokens": scritti,
                  "cache_read_input_tokens": 0, "output_tokens": uscita,
                  "cache_creation": {"ephemeral_1h_input_tokens": scritti,
                                     "ephemeral_5m_input_tokens": 0}},
        "modelUsage": {"claude-%s-5-5" % alias: {
            "inputTokens": 2, "outputTokens": uscita, "costUSD": costo}},
        "permission_denials": [], "uuid": uuid.uuid4().hex}
    doc.update(extra)
    if "usage-rotto" in modi():
        doc["usage"]["input_tokens"] = "boh"
    return doc


def ids_rubrica(prompt: str) -> List[str]:
    """Gli id delle affermazioni del tag rubric della consegna."""
    corpo = prompt.split("<rubric>", 1)[-1].split("</rubric>", 1)[0]
    return re.findall(r"(?m)^- ([a-z][a-z0-9_]*):", corpo)


def giudica(prompt: str) -> int:
    """Una chiamata del giudice: un esito per ogni id della rubrica."""
    ids = ids_rubrica(prompt)
    falsi = set()
    if "corto-no-giudice" in modi() and MARCA_CORTA in prompt and ids:
        falsi.add(ids[0])
    criteri = [{"id": i, "motivo": "Motivo del giudice finto per %s." % i,
                "rispettato": i not in falsi} for i in ids]
    extra: Dict[str, Any] = {"structured_output": {"criteri": criteri}}
    if "senza-structured" in modi():
        extra = {}
    if "fuori-schema" in modi():
        extra["structured_output"]["voto"] = 10
    if "errore-giudice" in modi():
        extra["is_error"] = True
    testo = json.dumps(extra.get("structured_output", {}), ensure_ascii=False)
    print(json.dumps(documento(testo, "haiku", token_da(prompt) + 400,
                               token_da(testo), 2, extra),
                     ensure_ascii=False))
    return 0


def caso_del(prompt: str) -> str:
    for chiave, caso in RICONOSCI.items():
        if chiave in prompt:
            return caso
    return "caso-1"


def risponde(argv: List[str], prompt: str) -> int:
    """Una risposta al caso del prompt."""
    corto = len(prompt.encode("utf-8")) < SOGLIA_CORTO
    testo = RISPOSTE[caso_del(prompt)]
    if corto and "corto-no-controlli" in modi():
        testo = re.sub(r"TK-2026-[0-9]+", "numero da definire", testo)
        testo += " Sicuramente torna presto."
    if corto:
        testo += " " + MARCA_CORTA
    testo += NOTA
    alias = valore(argv, "--model") or "sonnet"
    extra: Dict[str, Any] = {}
    if "errore-risposta" in modi():
        extra["is_error"] = True
    print(json.dumps(documento(testo, alias, token_da(prompt) + 500,
                               token_da(testo), 1, extra),
                     ensure_ascii=False))
    return 0


def main() -> int:
    argv = sys.argv[1:]
    if argv == ["--version"]:
        print("2.1.322 (Claude Code, finto)")
        return 0
    prompt = prompt_di(argv)
    registra(argv, prompt)
    for parola in modi():
        if parola.startswith("ko-se=") and parola[len("ko-se="):] in prompt:
            return 1
    if valore(argv, "--agent") == "giudice":
        return giudica(prompt)
    return risponde(argv, prompt)


if __name__ == "__main__":
    sys.exit(main())
