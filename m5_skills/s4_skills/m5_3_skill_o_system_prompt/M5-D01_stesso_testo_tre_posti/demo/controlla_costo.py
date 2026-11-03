"""controlla_costo.py -- lo stesso testo in tre posti: la demo M5-D01 alla
prova.

Legge, nella cartella data, gli stream di `claude -p --output-format
stream-json --verbose` delle esecuzioni, sei per ogni numero <n>:
  niente-<n>, skill-<n>, claude_md-<n>, append-<n>  la stessa domanda, che non
      ha bisogno del testo, nei quattro bracci;
  skill_invocata-<n>  nel braccio della skill, /procedure-assistenza con una
      domanda che il testo sa;
  skill_dopo-<n>      un'altra domanda nella stessa sessione, con --resume.

Di ogni stream conta la prima richiesta: input_tokens,
cache_creation_input_tokens e cache_read_input_tokens, sommati, del primo
messaggio dell'assistente della conversazione principale (parent_tool_use_id
null). Stampa, per esecuzione: righe e caratteri di testo.md, che sta accanto a
questo file; la tabella dei quattro bracci; i due confronti, «confermata» se la
skill costa meno, «non distinguibile» se costa uguale, «non confermata in questa
esecuzione» se costa di più, con «confermata n su N»; come dati, ogni braccio
sopra il braccio niente e append contro claude_md, che nessuna affermazione
ordina; la skill invocata meno quella non invocata, il turno dopo e le due
risposte. Un confronto non decide mai l'uscita.

Decidono l'uscita soltanto le segnalazioni: una chiamata a Skill nei bracci
claude_md, append o niente, dove la domanda non ha bisogno di nessun testo; un
braccio che non è quello che dovrebbe (la skill che manca dall'elenco skills di
system/init dove deve esserci, o che c'è dove non deve). Una chiamata a Skill
sulla domanda nel braccio della skill è un dato: la prima richiesta viene prima
della chiamata.

Uso:    python3 controlla_costo.py <cartella degli stream>
Uscita: 0 gli stream si leggono, nessuna segnalazione
        1 almeno una segnalazione
        2 uso sbagliato; la cartella che non c'è o non ha stream; uno stream
          che manca, vuoto, con una riga che non è un oggetto JSON, senza il
          risultato riuscito in fondo, senza system/init, senza un messaggio
          dell'assistente o con la sua usage che non va; testo.md che manca; un
          errore inatteso (una riga, mai un traceback)
"""
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Tuple

BRACCI = ("niente", "skill", "claude_md", "append")
SEGUITI = ("skill_invocata", "skill_dopo")
NOME = re.compile(r"^(%s)-([1-9][0-9]*)\.jsonl$" % "|".join(BRACCI + SEGUITI))
SKILL = "procedure-assistenza"
CON_LA_SKILL = ("skill",) + SEGUITI
SENZA_SKILL_CHIAMATE = ("niente", "claude_md", "append")
CAMPI = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 controlla_costo.py <cartella degli stream>\n"
LARGHEZZA = 12
RISPOSTA_MAX = 60


class Illeggibile(Exception):
    """Qualcosa che non si legge o che manca: uscita 2."""


class Stream(NamedTuple):
    """Che cosa dice lo stream di una chiamata."""
    prima: int
    skills: List[str]
    chiamate: List[str]
    risposta: str


def migliaia(numero: int) -> str:
    """Il numero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def con_segno(numero: int) -> str:
    """Il numero con il segno, senza segno lo zero."""
    if numero == 0:
        return "0"
    return ("+" if numero > 0 else "-") + migliaia(abs(numero))


def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi di uno stream riuscito; Illeggibile se non lo è."""
    nome = os.path.basename(percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8")
    except FileNotFoundError:
        raise Illeggibile("manca %s: %s" % (nome, RIFARE))
    except (OSError, UnicodeDecodeError) as exc:
        raise Illeggibile("%s non si legge (%s)" % (
            nome, getattr(exc, "strerror", None) or exc))
    if not testo.strip():
        raise Illeggibile("%s è vuoto: %s" % (nome, RIFARE))
    eventi = []
    # split("\n"), non splitlines(): un U+2028 in un testo JSON non chiude la
    # riga
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            evento = None
        if not isinstance(evento, dict):
            raise Illeggibile("%s, riga %d: non è JSON, o non un oggetto"
                              % (nome, numero))
        eventi.append(evento)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Illeggibile("%s non finisce con il risultato: la chiamata si è "
                          "interrotta? %s" % (nome, RIFARE))
    if ultimo.get("is_error") or ultimo.get("subtype", "success") != "success":
        raise Illeggibile("%s: claude ha restituito un errore; %s"
                          % (nome, RIFARE))
    return eventi


def skills_di(eventi: List[dict], nome: str) -> List[str]:
    """L'elenco skills del primo system/init."""
    for evento in eventi:
        if evento.get("type") == "system" and evento.get("subtype") == "init":
            elenco = evento.get("skills")
            if isinstance(elenco, list):
                return [str(s) for s in elenco]
            break
    raise Illeggibile("%s: manca system/init con l'elenco skills" % nome)


def prima_richiesta(eventi: List[dict], nome: str) -> int:
    """La somma dei tre campi di usage del primo messaggio dell'assistente
    della conversazione principale."""
    for evento in eventi:
        if evento.get("type") != "assistant" \
                or evento.get("parent_tool_use_id"):
            continue
        messaggio = evento.get("message")
        uso = messaggio.get("usage") if isinstance(messaggio, dict) else None
        if not isinstance(uso, dict):
            raise Illeggibile("%s: il primo messaggio non ha usage" % nome)
        valori = [uso.get(campo) for campo in CAMPI]
        if not all(isinstance(v, int) and not isinstance(v, bool)
                   for v in valori):
            raise Illeggibile("%s: usage senza i tre campi di token" % nome)
        if sum(valori) <= 0:
            raise Illeggibile("%s: il primo messaggio ha zero token: la "
                              "richiesta non è partita" % nome)
        return sum(valori)
    raise Illeggibile("%s: nessun messaggio dell'assistente nella "
                      "conversazione principale" % nome)


def chiamate_skill(eventi: List[dict]) -> List[str]:
    """input.skill di ogni tool_use Skill, una volta per id del blocco."""
    trovate, visti = [], set()
    for evento in eventi:
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") if isinstance(messaggio, dict) \
            else None
        if evento.get("type") != "assistant" \
                or not isinstance(contenuto, list):
            continue
        for blocco in contenuto:
            if not isinstance(blocco, dict) or blocco.get("name") != "Skill" \
                    or blocco.get("type") != "tool_use":
                continue
            ident = blocco.get("id")
            if ident is not None and ident in visti:
                continue
            visti.add(ident)
            ingresso = blocco.get("input")
            trovate.append(str(ingresso.get("skill", "?"))
                           if isinstance(ingresso, dict) else "?")
    return trovate


def leggi_stream(percorso: str) -> Stream:
    """Che cosa dice uno stream; Illeggibile se non si può dire."""
    nome = os.path.basename(percorso)
    eventi = eventi_di(percorso)
    risposta = eventi[-1].get("result")
    return Stream(prima_richiesta(eventi, nome), skills_di(eventi, nome),
                  chiamate_skill(eventi),
                  risposta if isinstance(risposta, str) else "")


def numeri_di(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella, in ordine."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Illeggibile("la cartella %s non esiste o non si apre (%s)"
                          % (cartella, exc.strerror or exc))
    numeri = {int(m.group(2)) for m in map(NOME.match, nomi) if m}
    if not numeri:
        raise Illeggibile("nessuno stream in %s: %s" % (cartella, RIFARE))
    return sorted(numeri)


def leggi_tutto(cartella: str, numeri: List[int]) -> Dict[Tuple[str, int],
                                                          Stream]:
    """Tutti gli stream. Li prova tutti, poi dice ogni problema in una volta:
    Illeggibile con una riga per stream."""
    letti: Dict[Tuple[str, int], Stream] = {}
    problemi = []
    for numero in numeri:
        for braccio in BRACCI + SEGUITI:
            percorso = os.path.join(cartella, "%s-%d.jsonl" % (braccio, numero))
            try:
                letti[(braccio, numero)] = leggi_stream(percorso)
            except Illeggibile as exc:
                problemi.append(str(exc))
    if problemi:
        raise Illeggibile("\n".join(problemi))
    return letti


def dati_del_testo() -> str:
    """Righe e caratteri di testo.md, accanto a questo file."""
    percorso = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            "testo.md")
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Illeggibile("manca testo.md accanto al controllo, o non si "
                          "legge (%s)"
                          % (getattr(exc, "strerror", None) or exc))
    return "testo.md: %d righe, %s caratteri." % (testo.count("\n"),
                                                  migliaia(len(testo)))


def verdetto(skill: int, altro: int) -> str:
    """Il confronto di un'esecuzione: la skill contro l'altro posto."""
    numeri = "%s token contro %s" % (migliaia(skill), migliaia(altro))
    if skill < altro:
        return "%s (%s)" % (CONFERMATA, numeri)
    if skill == altro:
        return "%s (%s)" % (NON_DISTINGUIBILE, numeri)
    return "%s (%s)" % (NON_CONFERMATA, numeri)


def stampa_tabella(letti: Dict[Tuple[str, int], Stream],
                   numeri: List[int]) -> None:
    """La prima richiesta di ogni braccio, per esecuzione."""
    print("Prima richiesta di ogni braccio, in token (input, cache creation e")
    print("cache read del primo messaggio dell'assistente):")
    print("esecuzione" + "".join(b.rjust(LARGHEZZA) for b in BRACCI))
    for numero in numeri:
        print(str(numero).rjust(10) + "".join(
            migliaia(letti[(b, numero)].prima).rjust(LARGHEZZA)
            for b in BRACCI))


def stampa_confronto(titolo: str, altro: str,
                     letti: Dict[Tuple[str, int], Stream],
                     numeri: List[int]) -> None:
    """Un confronto, esecuzione per esecuzione, e «confermata n su N»."""
    print(titolo)
    conferme = 0
    for numero in numeri:
        esito = verdetto(letti[("skill", numero)].prima,
                         letti[(altro, numero)].prima)
        conferme += esito.startswith(CONFERMATA)
        print("  esecuzione %d: %s" % (numero, esito))
    print("  %s %d su %d" % (CONFERMATA, conferme, len(numeri)))


def breve(testo: str) -> str:
    """La risposta su una riga, accorciata."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= RISPOSTA_MAX else riga[:RISPOSTA_MAX - 1] + "…"


def stampa_dati(letti: Dict[Tuple[str, int], Stream],
                numeri: List[int]) -> None:
    """I dati: sopra il braccio niente, l'invocata, Skill sulla domanda."""
    print("Come dati, sopra il braccio niente, e append contro claude_md:")
    for n in numeri:
        base = letti[("niente", n)].prima
        print("  esecuzione %d: skill %s, claude_md %s, append %s; append meno "
              "claude_md %s" % (
                  n, con_segno(letti[("skill", n)].prima - base),
                  con_segno(letti[("claude_md", n)].prima - base),
                  con_segno(letti[("append", n)].prima - base),
                  con_segno(letti[("append", n)].prima
                            - letti[("claude_md", n)].prima)))
    print("Come dati, la skill invocata e il turno dopo:")
    for n in numeri:
        non = letti[("skill", n)].prima
        inv, dopo = letti[("skill_invocata", n)], letti[("skill_dopo", n)]
        print("  esecuzione %d: non invocata %s; invocata %s (%s); turno dopo "
              "%s (%s)" % (n, migliaia(non), migliaia(inv.prima),
                           con_segno(inv.prima - non), migliaia(dopo.prima),
                           con_segno(dopo.prima - non)))
        print("    invocata: «%s»" % breve(inv.risposta))
        print("    turno dopo: «%s»" % breve(dopo.risposta))
    sulla_domanda = sum(1 for n in numeri if letti[("skill", n)].chiamate)
    print("Chiamate a Skill sulla domanda, nel braccio della skill: %d su %d."
          % (sulla_domanda, len(numeri)))


def segnalazioni(letti: Dict[Tuple[str, int], Stream],
                 numeri: List[int]) -> List[str]:
    """Ciò che non doveva succedere, una frase per caso."""
    trovate = []
    for n in numeri:
        for braccio in BRACCI + SEGUITI:
            stream, nome = letti[(braccio, n)], "%s-%d" % (braccio, n)
            if braccio in SENZA_SKILL_CHIAMATE and stream.chiamate:
                trovate.append("%s: una chiamata a Skill (%s), e la domanda "
                               "non ha bisogno di nessun testo"
                               % (nome, ", ".join(stream.chiamate)))
            if braccio in CON_LA_SKILL and SKILL not in stream.skills:
                trovate.append("%s: %s non è fra le skill dello stream: il "
                               "braccio non è quello che dovrebbe" % (nome,
                                                                      SKILL))
            if braccio not in CON_LA_SKILL and SKILL in stream.skills:
                trovate.append("%s: %s è fra le skill dello stream: il braccio "
                               "non è quello che dovrebbe" % (nome, SKILL))
    return trovate


def controlla(cartella: str) -> int:
    """Il controllo: stampa i dati e i verdetti, restituisce l'uscita 0 o 1."""
    testo = dati_del_testo()
    numeri = numeri_di(cartella)
    letti = leggi_tutto(cartella, numeri)
    print(testo)
    print()
    stampa_tabella(letti, numeri)
    print()
    stampa_confronto("Skill contro CLAUDE.md, «doesn't weigh … the way it "
                     "would in CLAUDE.md»:", "claude_md", letti, numeri)
    stampa_confronto("Skill contro append, «can have a higher context cost»:",
                     "append", letti, numeri)
    print()
    stampa_dati(letti, numeri)
    trovate = segnalazioni(letti, numeri)
    for frase in trovate:
        print("SEGNALAZIONE %s." % frase)
    return 1 if trovate else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, una riga per problema; l'uscita 2."""
    for riga in messaggio.split("\n"):
        sys.stderr.write("controlla_costo.py: %s\n" % riga)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except Illeggibile as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
