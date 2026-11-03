"""controlla_descrizione.py -- la descrizione decide: la demo M5-D02 alla prova.

Legge, nella cartella data, gli stream di `claude -p --output-format
stream-json --verbose` delle esecuzioni, cinque per ogni numero <n>, ognuna da
una cartella nuova, con lo stesso corpo e lo stesso nome della skill, prova-d02:
  vaga-<n>          la description vaga, la richiesta naturale;
  specifica-<n>     la description specifica, la stessa richiesta;
  near_miss-<n>     la description specifica, una richiesta vicina che chiede
                    altro;
  manuale-<n>       la description specifica con disable-model-invocation: true,
                    la richiesta naturale;
  manuale_nome-<n>  lo stesso file, con /prova-d02 davanti alla richiesta.

Una chiamata è un tool_use di nome Skill con input.skill nelle righe
«assistant»; è rifiutata se il suo id è nei permission_denials o se il suo
tool_result ha is_error. Il marcatore è AUD-01 nella risposta finale, e il corpo
nello stream è il messaggio utente «Base directory for this skill:» sulla
cartella di prova-d02.

Stampa: Skill sì o no per esecuzione; per ogni braccio Skill e marcatore «n su
N», come dati; il confronto, «confermata» se la specifica fa scattare la skill
più volte della vaga, «non distinguibile» se tante volte, «non confermata in
questa esecuzione» se meno, che non decide l'uscita; la near-miss, un dato; le
due verifiche del flag; la prima richiesta in token, un dato; le altre skill
chiamate, un dato.

Decidono l'uscita soltanto le segnalazioni: con il flag una chiamata a prova-d02
che non è stata rifiutata (la garanzia); /prova-d02 con il flag senza il
marcatore e senza il corpo nello stream; un braccio dove prova-d02 manca
dall'elenco skills di system/init, perché senza la skill un «no» non vorrebbe
dire niente. Una chiamata tentata e rifiutata non invoca niente, e una chiamata
a un'altra skill non è la garanzia: si stampano come dati.

Uso:    python3 controlla_descrizione.py <cartella degli stream>
Uscita: 0 gli stream si leggono, nessuna segnalazione
        1 almeno una segnalazione
        2 uso sbagliato; la cartella che non c'è o non ha stream; uno stream che
          manca, vuoto, con una riga che non è un oggetto JSON, senza il
          risultato riuscito in fondo o senza system/init; un errore inatteso
          (una riga, mai un traceback)
"""
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

BRACCI = ("vaga", "specifica", "near_miss", "manuale", "manuale_nome")
NOMI = {"vaga": "vaga", "specifica": "specifica", "near_miss": "near-miss",
        "manuale": "con il flag"}
NOME = re.compile(r"^(%s)-([1-9][0-9]*)\.jsonl$" % "|".join(BRACCI))
SKILL = "prova-d02"
MARCATORE = "AUD-01"
BASE = "Base directory for this skill:"
CAMPI = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
S_CONFRONTO = ("Specifica contro vaga, «vague descriptions reduce triggering "
               "accuracy»")
S_FLAG = "Con il flag, «Claude can't invoke the skill on its own»"
S_NOME = "/prova-d02 con il flag, «Include /skill-name in the prompt string»"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 controlla_descrizione.py <cartella degli stream>\n"
LARGHEZZA_NOME = 14
LARGHEZZA_RUN = 5


class Illeggibile(Exception):
    """Qualcosa che non si legge o che manca: uscita 2."""


class Stream(NamedTuple):
    """Che cosa dice lo stream di una chiamata."""
    skills: List[str]
    chiamate: List[str]
    riuscita: bool
    rifiutata: bool
    corpo: bool
    marcatore: bool
    prima: Optional[int]

    def altre(self) -> List[str]:
        """Le chiamate alle altre skill."""
        return [s for s in self.chiamate if s != SKILL]


def migliaia(numero: Optional[int]) -> str:
    """Il numero con il punto delle migliaia, o un trattino."""
    return "—" if numero is None else "{:,}".format(numero).replace(",", ".")


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


def blocchi(evento: dict) -> List[dict]:
    """I blocchi del contenuto di un messaggio."""
    messaggio = evento.get("message")
    contenuto = messaggio.get("content") if isinstance(messaggio, dict) \
        else None
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)]


def chiamate_di(eventi: List[dict]) -> Dict[str, str]:
    """Le chiamate a Skill: l'id del blocco -> input.skill, una volta per id."""
    trovate: Dict[str, str] = {}
    for evento in eventi:
        if evento.get("type") != "assistant":
            continue
        for blocco in blocchi(evento):
            if blocco.get("type") == "tool_use" \
                    and blocco.get("name") == "Skill":
                ingresso = blocco.get("input")
                trovate[str(blocco.get("id", len(trovate)))] = (
                    str(ingresso.get("skill", "?"))
                    if isinstance(ingresso, dict) else "?")
    return trovate


def rifiutati_di(eventi: List[dict]) -> List[str]:
    """Gli id delle chiamate rifiutate: nei permission_denials dei risultati, o
    con un tool_result che ha is_error."""
    rifiutati = []
    for evento in eventi:
        if evento.get("type") == "result":
            dinieghi = evento.get("permission_denials")
            for voce in dinieghi if isinstance(dinieghi, list) else []:
                if isinstance(voce, dict):
                    rifiutati.append(str(voce.get("tool_use_id")))
        if evento.get("type") == "user":
            for blocco in blocchi(evento):
                if blocco.get("type") == "tool_result" \
                        and blocco.get("is_error"):
                    rifiutati.append(str(blocco.get("tool_use_id")))
    return rifiutati


def corpo_arrivato(eventi: List[dict]) -> bool:
    """Vero se un messaggio utente porta il corpo di prova-d02."""
    prefisso_cartella = "/.claude/skills/" + SKILL
    for evento in eventi:
        if evento.get("type") != "user":
            continue
        for blocco in blocchi(evento):
            testo = blocco.get("text")
            if blocco.get("type") == "text" and isinstance(testo, str) \
                    and testo.startswith(BASE) \
                    and prefisso_cartella in testo.split("\n", 1)[0]:
                return True
    return False


def prima_richiesta(eventi: List[dict]) -> Optional[int]:
    """I tre campi di usage del primo messaggio dell'assistente, sommati: un
    dato; None se non ci sono o valgono zero."""
    for evento in eventi:
        if evento.get("type") != "assistant" \
                or evento.get("parent_tool_use_id"):
            continue
        messaggio = evento.get("message")
        uso = messaggio.get("usage") if isinstance(messaggio, dict) else None
        if not isinstance(uso, dict):
            return None
        valori = [uso.get(campo) for campo in CAMPI]
        if not all(isinstance(v, int) and not isinstance(v, bool)
                   for v in valori):
            return None
        return sum(valori) or None
    return None


def leggi_stream(percorso: str) -> Stream:
    """Che cosa dice uno stream; Illeggibile se non si può dire."""
    eventi = eventi_di(percorso)
    chiamate = chiamate_di(eventi)
    rifiutati = rifiutati_di(eventi)
    su_questa = [i for i, nome in chiamate.items() if nome == SKILL]
    risposta = eventi[-1].get("result")
    return Stream(
        skills_di(eventi, os.path.basename(percorso)), list(chiamate.values()),
        any(i not in rifiutati for i in su_questa),
        any(i in rifiutati for i in su_questa),
        corpo_arrivato(eventi),
        isinstance(risposta, str) and MARCATORE in risposta,
        prima_richiesta(eventi))


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
        for braccio in BRACCI:
            percorso = os.path.join(cartella, "%s-%d.jsonl" % (braccio, numero))
            try:
                letti[(braccio, numero)] = leggi_stream(percorso)
            except Illeggibile as exc:
                problemi.append(str(exc))
    if problemi:
        raise Illeggibile("\n".join(problemi))
    return letti


def quante(letti: Dict[Tuple[str, int], Stream], braccio: str,
           numeri: List[int]) -> int:
    """In quante esecuzioni di un braccio c'è una chiamata a prova-d02."""
    return sum(1 for n in numeri if SKILL in letti[(braccio, n)].chiamate)


def stampa_conteggi(letti: Dict[Tuple[str, int], Stream],
                    numeri: List[int]) -> None:
    """Skill per esecuzione e, per braccio, Skill e marcatore «n su N»."""
    tot = len(numeri)
    print("Skill su %s, esecuzione per esecuzione:" % SKILL)
    print("braccio".ljust(LARGHEZZA_NOME)
          + "".join(str(n).rjust(LARGHEZZA_RUN) for n in numeri))
    for braccio in BRACCI[:4]:
        print(NOMI[braccio].ljust(LARGHEZZA_NOME) + "".join(
            ("sì" if SKILL in letti[(braccio, n)].chiamate else "no")
            .rjust(LARGHEZZA_RUN) for n in numeri))
    print()
    print("Come dati, le chiamate e il marcatore %s nella risposta:"
          % MARCATORE)
    for braccio in BRACCI[:4]:
        marcate = sum(1 for n in numeri if letti[(braccio, n)].marcatore)
        print("%s: Skill %d su %d, marcatore %d su %d" % (
            NOMI[braccio], quante(letti, braccio, numeri), tot, marcate, tot))
    marcate = sum(1 for n in numeri if letti[("manuale_nome", n)].marcatore)
    corpi = sum(1 for n in numeri if letti[("manuale_nome", n)].corpo)
    print("/prova-d02 con il flag: marcatore %d su %d, corpo nello stream %d "
          "su %d" % (marcate, tot, corpi, tot))


def confronto(specifica: int, vaga: int, tot: int) -> str:
    """Il confronto: la specifica contro la vaga."""
    if specifica > vaga:
        return "%s (%d su %d contro %d su %d)" % (CONFERMATA, specifica, tot,
                                                  vaga, tot)
    if specifica == vaga:
        return "%s (%d su %d e %d su %d)" % (NON_DISTINGUIBILE, specifica, tot,
                                             vaga, tot)
    return "%s (%d su %d contro %d su %d)" % (NON_CONFERMATA, specifica, tot,
                                              vaga, tot)


def stampa_garanzia(titolo: str, cattive: List[str], tot: int) -> None:
    """Una garanzia: confermata in tutte, o quali non la reggono."""
    if cattive:
        print("%s: %s (%s)" % (titolo, NON_CONFERMATA, ", ".join(cattive)))
    else:
        print("%s: %s %d su %d" % (titolo, CONFERMATA, tot, tot))


def stampa_verdetti(letti: Dict[Tuple[str, int], Stream], numeri: List[int],
                    cattive: Tuple[List[str], List[str]]) -> None:
    """Il confronto, la near-miss come dato, le due verifiche del flag."""
    tot = len(numeri)
    print("%s: %s" % (S_CONFRONTO, confronto(quante(letti, "specifica", numeri),
                                             quante(letti, "vaga", numeri),
                                             tot)))
    print("Near-miss, come dato: Skill %d su %d; una near-miss non dovrebbe "
          "far scattare la skill" % (quante(letti, "near_miss", numeri), tot))
    stampa_garanzia(S_FLAG, cattive[0], tot)
    stampa_garanzia(S_NOME, cattive[1], tot)


def stampa_dati(letti: Dict[Tuple[str, int], Stream],
                numeri: List[int]) -> None:
    """La prima richiesta, le chiamate rifiutate, le altre skill: dati."""
    print("Come dati, la prima richiesta in token:")
    for n in numeri:
        print("  esecuzione %d: %s" % (n, ", ".join(
            "%s %s" % (NOMI[b], migliaia(letti[(b, n)].prima))
            for b in BRACCI[:4])))
    for chiave, stream in sorted(letti.items()):
        nome = "%s-%d" % chiave
        if stream.rifiutata:
            print("Come dato, %s: tentata e rifiutata." % nome)
        if stream.altre():
            print("Altre skill chiamate, come dato: %s: %s" % (
                nome, ", ".join(stream.altre())))


def controlla(cartella: str) -> int:
    """Il controllo: stampa i dati e i verdetti, restituisce l'uscita 0 o 1."""
    numeri = numeri_di(cartella)
    letti = leggi_tutto(cartella, numeri)
    frasi, flag, nome_cattive = [], [], []
    for chiave, stream in sorted(letti.items()):
        etichetta = "%s-%d" % chiave
        if SKILL not in stream.skills:
            frasi.append("%s: %s non è fra le skill dello stream: senza la "
                         "skill questo braccio non vale" % (etichetta, SKILL))
        if chiave[0] in ("manuale", "manuale_nome") and stream.riuscita:
            flag.append(etichetta)
            frasi.append("%s: Claude ha invocato %s da solo, con "
                         "disable-model-invocation: la garanzia non tiene"
                         % (etichetta, SKILL))
        if chiave[0] == "manuale_nome" \
                and not (stream.marcatore or stream.corpo):
            nome_cattive.append(etichetta)
            frasi.append("%s: né il marcatore né il corpo nello stream: "
                         "/prova-d02 non ha girato" % etichetta)
    stampa_conteggi(letti, numeri)
    print()
    stampa_verdetti(letti, numeri, (flag, nome_cattive))
    print()
    stampa_dati(letti, numeri)
    for frase in frasi:
        print("SEGNALAZIONE %s." % frase)
    return 1 if frasi else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, una riga per problema; l'uscita 2."""
    for riga in messaggio.split("\n"):
        sys.stderr.write("controlla_descrizione.py: %s\n" % riga)
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
