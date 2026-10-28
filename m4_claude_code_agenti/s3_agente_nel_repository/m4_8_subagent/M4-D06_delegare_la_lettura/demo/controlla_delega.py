"""controlla_delega.py -- delegare la lettura dei log a un subagent, o
leggerli da sé: la demo M4-D06 alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente), gli
stream-json delle coppie in risposte/: delega-<n>.jsonl, la domanda sul
guasto di martedì 8 settembre su olt-pergine-01 (quando è cominciato,
quando è finito, quante linee di clienti, cioè ONT, ha coinvolto; la
risposta in una riga 'inizio: HH:MM | fine: HH:MM | ONT: N') con la
richiesta di delegare la lettura dei log al subagent Explore, e
senza-<n>.jsonl, la
stessa domanda con la richiesta di leggerli da sé; le due esecuzioni di una
coppia differiscono soltanto nella prima frase del prompt. Le coppie sono
i numeri per cui c'è almeno uno dei due file, e ognuna deve averli tutti e
due.

Per ogni esecuzione stampa, come dati: gli strumenti della conversazione
principale (i messaggi con parent_tool_use_id null), con le chiamate Agent
e il tipo di subagent, e gli strumenti del subagent (i messaggi con
parent_tool_use_id valorizzato); i caratteri dei risultati degli strumenti
dalle due parti; il contesto principale all'ultima richiesta (input e
cache dell'ultimo messaggio dell'assistente della conversazione
principale); i token di tutti i modelli (modelUsage del risultato finale:
in entrata input e cache, in uscita output); la durata, dal primo
all'ultimo orario dello stream; la risposta (il testo del risultato
finale), confrontata con la verità se --verita la dà.

Poi i verdetti, «confermata», «non confermata in questa esecuzione» oppure
«non distinguibile (perché)»:
  La conversazione principale vede solo il risultato del subagent: in ogni
      esecuzione con la delega in cui il subagent ha lavorato (lo stream
      mostra i risultati dei suoi strumenti), nessun messaggio della
      conversazione principale porta un risultato che non sia di una sua
      chiamata: né di una chiamata del subagent, né di una che lo stream
      non mostra. È una garanzia: un'eccezione fa uscire con 1. Senza
      subagent, o senza il suo lavoro nello stream, non distinguibile; se
      nessuna esecuzione la mette alla prova, uscita 1 (non ancora).
  Un subagent tiene i log fuori dalla conversazione principale: coppia per
      coppia, il contesto principale all'ultima richiesta, con la delega
      contro senza: confermata se è più piccolo con la delega; non
      distinguibile se è uguale, o se la coppia non differisce nella
      delega (nessun subagent con la delega, uno anche senza); non
      confermata in questa esecuzione se è più grande. Poi «confermata n
      su N». È un confronto: il verdetto si stampa e non decide l'uscita.
I token di tutti i modelli e le risposte giuste si stampano come dati, mai
come un verdetto.

Uso:    python3 controlla_delega.py [--verita FILE] [<spazio di lavoro>]
          --verita  il JSON della verità, {"inizio": "HH:MM", "fine":
                    "HH:MM", "ont": N}; senza, le risposte si stampano e
                    non si confrontano. La verità non sta nello spazio di
                    lavoro: verifica.sh la passa dalla cartella
                    dell'elemento.
Uscita: 0 almeno una coppia completa, ogni stream si legge, almeno
          un'esecuzione mette alla prova la garanzia e la garanzia tiene (il
          confronto non decide l'uscita)
        1 manca risposte/; nessuna coppia; una coppia a metà; uno stream
          che manca, vuoto, con una riga che non è un oggetto JSON o senza
          il risultato riuscito in fondo; la garanzia non confermata, o
          nessuna esecuzione che la mette alla prova
        2 uso sbagliato; lo spazio di lavoro assente; la verità che non si
          legge o non va; un file che non si legge; un errore inatteso (una
          riga, mai un traceback)
"""
import datetime
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

CARTELLA = "risposte"
LATI = ("delega", "senza")
NOME = re.compile(r"^(delega|senza)-([1-9][0-9]*)\.jsonl$")
ORA = re.compile(r"^([01][0-9]|2[0-3]):[0-5][0-9]$")
LETTURE = (
    ("inizio", re.compile(r"(?i)\binizio\s*[:=]\s*(\d{1,2})[:.](\d\d)")),
    ("fine", re.compile(r"(?i)\bfine\s*[:=]\s*(\d{1,2})[:.](\d\d)")),
    ("ont", re.compile(r"(?i)\bont\s*[:=]\s*(\d+)")))
# per campo: il nome nel messaggio, «atteso» accordato, «mancante» accordato
PAROLE = {"inizio": ("inizio", "atteso", "mancante"),
          "fine": ("fine", "attesa", "mancante"),
          "ont": ("ONT", "attese", "mancanti")}
AGENTI = ("Agent", "Task")
CONTESTO = ("input_tokens", "cache_read_input_tokens",
            "cache_creation_input_tokens")
ENTRATA = ("inputTokens", "cacheReadInputTokens", "cacheCreationInputTokens")
S_GARANZIA = "La conversazione principale vede solo il risultato del subagent"
S_CONTESTO = "Un subagent tiene i log fuori dalla conversazione principale"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
SEGNALARE = ("La garanzia non confermata è un esito da segnalare: la "
             "conversazione principale non dovrebbe vedere i passaggi del "
             "subagent.")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NESSUNA = ("Non ancora: nessuna coppia in risposte/ (delega-<n>.jsonl e "
           "senza-<n>.jsonl): eseguite i passi del README.")
NON_ANCORA = ("Non ancora: una risposta manca o non va (qui sopra); rifate "
              "quella chiamata, poi rilanciate il controllo.")
NESSUNA_PROVA = ("Non ancora: in nessuna esecuzione con la delega lo stream "
                 "mostra il lavoro di un subagent, e la garanzia non si è "
                 "potuta mettere alla prova: rifate la coppia.")
FRAZIONE = re.compile(r"(:\d\d)\.(\d+)")
RIFARE = "rifate quella chiamata (il passo 2 del README)"
USO = ("Uso: python3 controlla_delega.py [--verita FILE] "
       "[<spazio di lavoro>]\n")


class Precondizione(Exception):
    """Un file d'ingresso che manca, non si legge o non va: uscita 2."""


class Mancante(Exception):
    """Una risposta che manca o non va: uscita 1."""


class Verita(NamedTuple):
    """L'inizio e la fine del guasto (HH:MM) e le linee di clienti
    coinvolte (ONT)."""
    inizio: str
    fine: str
    ont: int


class Esecuzione(NamedTuple):
    """Che cosa dice lo stream di un'esecuzione."""
    principale: Dict[str, int]
    tipi: List[str]
    subagent: Dict[str, int]
    caratteri: Tuple[int, int]
    perdite: List[str]
    risultati_subagent: int
    contesto: Optional[int]
    modelli: Tuple[int, int]
    durata: Optional[float]
    risposta: str

    def delega(self) -> bool:
        """Vero se la conversazione principale ha lanciato un subagent."""
        return any(self.principale.get(nome) for nome in AGENTI)


def migliaia(numero: int) -> str:
    """Il numero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def leggi_verita(percorso: str) -> Verita:
    """La verità; Precondizione se non si legge o non va."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError, RecursionError) as exc:
        raise Precondizione("la verità %s non si legge (%s)" % (
            percorso, getattr(exc, "strerror", None) or exc))
    if not isinstance(doc, dict):
        doc = {}
    inizio, fine, ont = doc.get("inizio"), doc.get("fine"), doc.get("ont")
    if not (isinstance(inizio, str) and ORA.match(inizio)
            and isinstance(fine, str) and ORA.match(fine)
            and isinstance(ont, int) and not isinstance(ont, bool)
            and ont >= 0):
        raise Precondizione("la verità %s non va: attesi «inizio» e «fine» "
                            "come HH:MM e «ont», un intero" % percorso)
    return Verita(inizio, fine, ont)


def leggi_stream(rel: str) -> List[dict]:
    """Gli eventi di uno stream-json riuscito di claude -p. Mancante se
    manca o non va; Precondizione se non si legge."""
    if not os.path.lexists(rel):
        raise Mancante("manca %s: %s" % (rel, RIFARE))
    try:
        with open(rel, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (rel, exc.strerror or exc))
    if not testo.strip():
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? %s"
                       % (rel, RIFARE))
    eventi = []
    # split("\n"), non splitlines(): un U+2028 dentro un testo JSON non
    # chiude la riga
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            raise Mancante("%s, riga %d: non è JSON; %s"
                           % (rel, numero, RIFARE))
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un oggetto JSON; %s"
                           % (rel, numero, RIFARE))
        eventi.append(evento)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato: la "
                       "chiamata si è interrotta? %s" % (rel, RIFARE))
    if ultimo.get("is_error") or ultimo.get("subtype", "success") != "success":
        raise Mancante("%s: claude ha restituito un errore; %s"
                       % (rel, RIFARE))
    return eventi


def blocchi(evento: dict) -> List[dict]:
    """I blocchi del contenuto di un messaggio."""
    messaggio = evento.get("message")
    contenuto = messaggio.get("content") if isinstance(messaggio, dict) \
        else None
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)]


def lunghezza(contenuto: object) -> int:
    """I caratteri del contenuto di un risultato di uno strumento."""
    if isinstance(contenuto, str):
        return len(contenuto)
    if isinstance(contenuto, list):
        return sum(len(str(b.get("text", ""))) for b in contenuto
                   if isinstance(b, dict))
    return 0 if contenuto is None else len(json.dumps(contenuto))


def chiamate(eventi: List[dict]) -> Tuple[Dict[str, int], List[str],
                                          Dict[str, int], set]:
    """Gli strumenti della conversazione principale e del subagent, una
    volta per id; i tipi di subagent lanciati; gli id delle chiamate della
    conversazione principale."""
    principale: Dict[str, int] = {}
    subagent: Dict[str, int] = {}
    tipi: List[str] = []
    del_principale, visti = set(), set()
    for evento in eventi:
        if evento.get("type") != "assistant":
            continue
        padre = evento.get("parent_tool_use_id")
        for blocco in blocchi(evento):
            ident = str(blocco.get("id", ""))
            if blocco.get("type") != "tool_use" or (ident and ident in visti):
                continue
            visti.add(ident)
            nome = str(blocco.get("name", "?"))
            if padre:
                subagent[nome] = subagent.get(nome, 0) + 1
                continue
            principale[nome] = principale.get(nome, 0) + 1
            del_principale.add(ident)
            ingresso = blocco.get("input")
            if nome in AGENTI and isinstance(ingresso, dict):
                tipi.append(str(ingresso.get("subagent_type", "?")))
    return principale, tipi, subagent, del_principale


def risultati(eventi: List[dict], del_principale: set) -> Tuple[
        Tuple[int, int], List[str], int]:
    """(i caratteri dei risultati nella principale e nel subagent), gli id
    dei risultati in un messaggio della principale che non sono di una sua
    chiamata (di una chiamata del subagent, o di una che lo stream non
    mostra), quanti risultati ha il subagent."""
    principale = subagent = conta = 0
    perdite: List[str] = []
    for evento in eventi:
        if evento.get("type") not in ("user", "assistant"):
            continue
        padre = evento.get("parent_tool_use_id")
        for blocco in blocchi(evento):
            if blocco.get("type") != "tool_result":
                continue
            caratteri = lunghezza(blocco.get("content"))
            ident = str(blocco.get("tool_use_id", ""))
            if padre:
                subagent += caratteri
                conta += 1
            else:
                principale += caratteri
                if ident not in del_principale:
                    perdite.append(ident or "senza id")
    return (principale, subagent), perdite, conta


def contesto(eventi: List[dict]) -> Optional[int]:
    """Input e cache dell'ultimo messaggio dell'assistente della
    conversazione principale; None se non c'è, se quel messaggio non ha
    usage o se vale zero."""
    ultimo = None
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" \
                or evento.get("parent_tool_use_id"):
            continue
        uso = messaggio.get("usage") if isinstance(messaggio, dict) else None
        totale = sum(int(uso.get(k) or 0) for k in CONTESTO) \
            if isinstance(uso, dict) else 0
        ultimo = totale or None
    return ultimo


def modelli(eventi: List[dict]) -> Tuple[int, int]:
    """I token di tutti i modelli dal modelUsage del risultato finale: (in
    entrata, in uscita)."""
    uso = eventi[-1].get("modelUsage")
    entrata = uscita = 0
    for dati in (uso.values() if isinstance(uso, dict) else []):
        if isinstance(dati, dict):
            entrata += sum(int(dati.get(k) or 0) for k in ENTRATA)
            uscita += int(dati.get("outputTokens") or 0)
    return entrata, uscita


def durata(eventi: List[dict]) -> Optional[float]:
    """I secondi dal primo all'ultimo orario dello stream."""
    orari = []
    for evento in eventi:
        valore = evento.get("timestamp")
        if not isinstance(valore, str):
            continue
        # Python 3.8 legge soltanto 3 o 6 cifre di frazione: si portano a 6
        valore = FRAZIONE.sub(lambda m: "%s.%s" % (
            m.group(1), (m.group(2) + "000000")[:6]), valore)
        try:
            ora = datetime.datetime.fromisoformat(
                valore.replace("Z", "+00:00"))
        except ValueError:
            continue
        if ora.tzinfo is None:
            ora = ora.replace(tzinfo=datetime.timezone.utc)
        orari.append(ora)
    if len(orari) < 2:
        return None
    return (max(orari) - min(orari)).total_seconds()


def analizza(eventi: List[dict]) -> Esecuzione:
    """Che cosa dice lo stream di un'esecuzione."""
    principale, tipi, subagent, del_principale = chiamate(eventi)
    caratteri, perdite, conta = risultati(eventi, del_principale)
    risposta = eventi[-1].get("result")
    return Esecuzione(principale, tipi, subagent, caratteri, perdite, conta,
                      contesto(eventi), modelli(eventi), durata(eventi),
                      risposta if isinstance(risposta, str) else "")


def leggi_risposta(testo: str) -> Dict[str, str]:
    """Inizio, fine e ONT della risposta, quelli che ci sono."""
    pulito = testo.replace("**", "").replace("`", "")
    trovati: Dict[str, str] = {}
    for campo, regola in LETTURE:
        trovato = regola.search(pulito)
        if trovato and campo == "ont":
            trovati[campo] = str(int(trovato.group(1)))
        elif trovato:
            trovati[campo] = "%02d:%s" % (int(trovato.group(1)),
                                         trovato.group(2))
    return trovati


def giudica_risposta(testo: str, verita: Verita) -> str:
    """giusta, sbagliata (perché) oppure senza la riga."""
    trovati = leggi_risposta(testo)
    if not trovati:
        return "senza la riga"
    sbagli = []
    for campo, atteso in (("inizio", verita.inizio), ("fine", verita.fine),
                          ("ont", str(verita.ont))):
        nome, accordo, assente = PAROLE[campo]
        letto = trovati.get(campo)
        if letto is None:
            sbagli.append("%s %s" % (nome, assente))
        elif letto != atteso:
            sbagli.append("%s %s, %s %s" % (nome, letto, accordo, atteso))
    return "sbagliata (%s)" % ", ".join(sbagli) if sbagli else "giusta"


def strumenti_testo(conti: Dict[str, int], tipi: List[str]) -> str:
    """Gli strumenti chiamati, con il tipo dei subagent lanciati."""
    voci = []
    for nome, quante in conti.items():
        if nome in AGENTI:
            voci.append("%s %d (%s)" % (nome, quante, ", ".join(tipi) or "?"))
        else:
            voci.append("%s %d" % (nome, quante))
    return ", ".join(voci) or "nessuno"


def stampa(lato: str, n: int, es: Esecuzione,
           verita: Optional[Verita]) -> None:
    """Le due righe dei dati di un'esecuzione."""
    principale, subagent = es.caratteri
    if es.subagent or es.delega():
        car = "%s caratteri nel subagent, %s nella conversazione principale" \
            % (migliaia(subagent), migliaia(principale))
    else:
        car = "%s caratteri nella conversazione principale" % migliaia(
            principale)
    contesto_ = "—" if es.contesto is None else "%s token" % migliaia(
        es.contesto)
    tempo = "—" if es.durata is None else "%d s" % round(es.durata)
    print("%s, %d: strumenti: %s; strumenti del subagent: %s; risultati "
          "degli strumenti: %s; contesto principale all'ultima richiesta: "
          "%s; tutti i modelli: %s token in entrata, %s in uscita; durata: "
          "%s" % (lato, n, strumenti_testo(es.principale, es.tipi),
                  strumenti_testo(es.subagent, []), car, contesto_,
                  migliaia(es.modelli[0]), migliaia(es.modelli[1]), tempo))
    risposta = " ".join(es.risposta.split())
    if len(risposta) > 160:
        risposta = risposta[:159] + "…"
    if verita is None:
        print("  risposta: «%s» (nessuna verità data: non si confronta)"
              % risposta)
    else:
        print("  risposta: «%s»: %s" % (risposta,
                                       giudica_risposta(es.risposta, verita)))


def verdetto_garanzia(es: Esecuzione) -> str:
    """La garanzia su un'esecuzione con la delega: la mette alla prova
    soltanto un subagent che nello stream ha lavorato."""
    if not es.delega():
        return "%s (nessun subagent in questa esecuzione)" % NON_DISTINGUIBILE
    if es.perdite:
        return ("%s (nella conversazione principale un risultato che non è "
                "di una sua chiamata: %s)" % (NON_CONFERMATA,
                                             ", ".join(es.perdite)))
    if not es.risultati_subagent:
        return "%s (nessun risultato di strumento del subagent nello " \
            "stream)" % NON_DISTINGUIBILE
    return "%s (%d risultati di strumenti del subagent, nessuno nella " \
        "conversazione principale)" % (CONFERMATA, es.risultati_subagent)


def verdetto_contesto(con: Esecuzione, senza: Esecuzione) -> str:
    """Il confronto di una coppia: il contesto principale con la delega
    contro senza."""
    if not con.delega():
        return "%s (nessun subagent nell'esecuzione con la delega)" % (
            NON_DISTINGUIBILE)
    if senza.delega():
        return "%s (un subagent anche nell'esecuzione senza delega)" % (
            NON_DISTINGUIBILE)
    if con.contesto is None or senza.contesto is None:
        return "%s (manca il contesto di un'esecuzione)" % NON_DISTINGUIBILE
    if con.contesto == senza.contesto:
        return "%s (lo stesso contesto: %s token)" % (
            NON_DISTINGUIBILE, migliaia(con.contesto))
    numeri = "%s token contro %s" % (migliaia(con.contesto),
                                     migliaia(senza.contesto))
    if con.contesto < senza.contesto:
        return "%s (%s)" % (CONFERMATA, numeri)
    return "%s (%s)" % (NON_CONFERMATA, numeri)


def coppie() -> List[int]:
    """I numeri delle coppie di risposte/, in ordine."""
    numeri = set()
    for nome in os.listdir(CARTELLA):
        trovato = NOME.match(nome)
        if trovato:
            numeri.add(int(trovato.group(2)))
    return sorted(numeri)


def avviso(messaggio: str) -> None:
    """Una risposta da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_delega.py: %s\n" % messaggio)


def leggi_tutto(numeri: List[int]) -> Optional[
        Dict[Tuple[str, int], Esecuzione]]:
    """Le esecuzioni delle coppie; None se una manca o non va (detto su
    STDERR)."""
    esecuzioni: Dict[Tuple[str, int], Esecuzione] = {}
    mancanti = 0
    for n in numeri:
        for lato in LATI:
            try:
                esecuzioni[(lato, n)] = analizza(leggi_stream(
                    "%s/%s-%d.jsonl" % (CARTELLA, lato, n)))
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
    return None if mancanti else esecuzioni


def riepiloghi(es: Dict[Tuple[str, int], Esecuzione], numeri: List[int],
               verita: Optional[Verita]) -> Tuple[bool, bool]:
    """I verdetti e i riepiloghi. Returns: (vero se la garanzia tiene, vero
    se almeno un'esecuzione l'ha messa alla prova)."""
    garanzie, confronti = [], []
    for n in numeri:
        verdetto = verdetto_garanzia(es[("delega", n)])
        print("%s (delega, %d): %s" % (S_GARANZIA, n, verdetto))
        if not verdetto.startswith(NON_DISTINGUIBILE):
            garanzie.append(verdetto.startswith(CONFERMATA))
    for n in numeri:
        verdetto = verdetto_contesto(es[("delega", n)], es[("senza", n)])
        confronti.append(verdetto.startswith(CONFERMATA))
        print("%s (coppia %d): %s" % (S_CONTESTO, n, verdetto))
    if not garanzie:
        print("%s: %s (nessun subagent in nessuna esecuzione)"
              % (S_GARANZIA, NON_DISTINGUIBILE))
    elif all(garanzie):
        print("%s: %s %d su %d" % (S_GARANZIA, CONFERMATA, len(garanzie),
                                   len(garanzie)))
    else:
        print("%s: %s (in %d esecuzioni su %d)" % (
            S_GARANZIA, NON_CONFERMATA, garanzie.count(False), len(garanzie)))
    print("%s: %s %d su %d" % (S_CONTESTO, CONFERMATA, confronti.count(True),
                               len(confronti)))
    entrate = {lato: sum(es[(lato, n)].modelli[0] for n in numeri)
               for lato in LATI}
    dati = "Come dati, tutti i modelli: %s token in entrata con la delega, " \
        "%s senza" % (migliaia(entrate["delega"]), migliaia(entrate["senza"]))
    if verita is not None:
        giuste = {lato: sum(1 for n in numeri if giudica_risposta(
            es[(lato, n)].risposta, verita) == "giusta") for lato in LATI}
        dati += "; risposte giuste: %d su %d con la delega, %d su %d senza" % (
            giuste["delega"], len(numeri), giuste["senza"], len(numeri))
    print(dati + ".")
    return all(garanzie), bool(garanzie)


def controlla(verita: Optional[Verita]) -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa i
    dati e i verdetti e restituisce l'uscita 0 o 1."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    numeri = coppie()
    if not numeri:
        print(NESSUNA)
        return 1
    esecuzioni = leggi_tutto(numeri)
    if esecuzioni is None:
        print(NON_ANCORA)
        return 1
    for n in numeri:
        for lato in LATI:
            stampa(lato, n, esecuzioni[(lato, n)], verita)
    tiene, provata = riepiloghi(esecuzioni, numeri, verita)
    if not tiene:
        print(SEGNALARE)
        return 1
    if not provata:
        print(NESSUNA_PROVA)
        return 1
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    file_verita: Optional[str] = None
    posizionali: List[str] = []
    resto = list(argv)
    while resto:
        arg = resto.pop(0)
        if arg == "--verita":
            if not resto:
                return uso("--verita vuole un file")
            file_verita = resto.pop(0)
        elif arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        else:
            posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    try:
        verita = None if file_verita is None else leggi_verita(file_verita)
    except Precondizione as exc:
        return errore(str(exc))
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla(verita)
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
