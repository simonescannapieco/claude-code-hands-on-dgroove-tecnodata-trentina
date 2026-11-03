"""controlla_garanzie.py -- le tre garanzie della demo M5-D03 alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente), gli stream
che in_classe.sh lascia in risposte/, un'esecuzione per numero n, e i due
segreti, risposte/codice.txt e risposte/parola.txt. Per ogni n ci sono undici
stream, i bracci di quattro coppie che differiscono in una cosa sola:
  codice    codice-con-n, !`cat codice.txt` nel corpo della skill;
            codice-senza-n, `cat codice.txt` come testo;
  comando   comando-con-n, !`bash conta.sh` con allowed-tools: Bash(bash
            conta.sh); comando-senza-n, senza il campo;
  permesso  permesso-con-n, un corpo che chiede di eseguire bash conta.sh, con
            il campo; permesso-con-n-dopo, il messaggio dopo, con --resume, che
            lo chiede di nuovo; permesso-senza-n, senza il campo;
  parola    parola-inline-n-prima e parola-fork-n-prima, un primo turno che dice
            la parola; parola-inline-n e parola-fork-n, /prova-parola con
            --resume, senza context: fork e con.

Per ogni braccio stampa, come dati, la risposta, gli strumenti chiamati, ciò che
la coppia guarda, i turni, i token e i secondi su ogni risultato. Poi, per ogni
coppia di ogni esecuzione, il verdetto, «confermata», «non confermata in questa
esecuzione» oppure «non distinguibile (perché)»:
  codice    con ! il codice è nella risposta e non c'è nessuna chiamata a uno
            strumento; senza ! c'è una chiamata, oppure il dato non c'è;
  comando   con il campo la sentinella di conta.sh è nella risposta, senza
            nessuna chiamata; senza il campo l'invocazione si ferma: il
            messaggio «Shell command permission check failed», zero turni;
  permesso  con il campo il comando gira; al messaggio dopo è negato; senza il
            campo è negato. Negato vuol dire nei permission_denials del
            risultato;
  parola    senza context: fork la parola torna nella risposta; con context:
            fork no, e lo stream mostra il subagent.
Sono garanzie del prodotto: ognuna deve valere a ogni esecuzione. Una garanzia
non confermata è un esito da segnalare; una coppia che non mostra la differenza
(Claude non ha tentato, o ha chiamato uno strumento dove il dato doveva arrivare
senza) non dice niente sulla garanzia, ma non la mette alla prova. Tutte e due
fanno uscire con 1. Il controllo legge gli stream, mai un file di esiti.

Uso:    python3 controlla_garanzie.py [<spazio di lavoro>]
        python3 controlla_garanzie.py --sessione <stream>
          stampa l'ID di sessione di uno stream (in_classe.sh lo usa per
          --resume); 1 se lo stream manca o non ce l'ha
Uscita: 0 almeno un'esecuzione completa, ogni stream si legge, ogni garanzia
          confermata
        1 manca risposte/; nessuna esecuzione; uno stream o un segreto che
          manca, vuoto, una riga che non è un oggetto JSON, senza il risultato
          riuscito in fondo, un risultato senza num_turns; una garanzia non
          confermata; una coppia non distinguibile
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si legge;
          un errore inatteso (una riga, mai un traceback)
"""
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

CARTELLA = "risposte"
SENTINELLA = "sentinella-4216"
MESSAGGIO_FERMO = "Shell command permission check failed"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RE_NOME = re.compile(r"^(?:codice|comando|permesso|parola)-"
                     r"(?:con|senza|inline|fork)-([1-9][0-9]*)"
                     r"(?:-prima|-dopo)?\.jsonl$")
RE_CONTA = re.compile(r"(?:^|[\s;&|])(?:(?:ba)?sh\s+(?:\./)?conta\.sh|"
                      r"\./conta\.sh)(?:$|[\s;&|])")
STREAM = ("codice-con-%d", "codice-senza-%d", "comando-con-%d",
          "comando-senza-%d", "permesso-con-%d", "permesso-con-%d-dopo",
          "permesso-senza-%d", "parola-inline-%d-prima", "parola-inline-%d",
          "parola-fork-%d-prima", "parola-fork-%d")
SKILL = {"codice": "prova-codice", "comando": "prova-conta",
         "permesso": "prova-esegui", "parola": "prova-parola"}
ETICHETTE = (("codice", "! porta il dato prima che Claude legga"),
             ("comando", "Un comando non consentito ferma l'invocazione"),
             ("permesso", "allowed-tools vale per un turno"),
             ("parola",
              "Con context: fork il subagent non vede la conversazione"))
TUTTE = "Ogni garanzia è confermata in ogni esecuzione."
SEGNALARE = ("Una garanzia non confermata è un esito da segnalare: lo stream "
             "qui sopra dice dove.")
NON_ANCORA = ("Non ancora: una coppia non ha mostrato la differenza, e la "
              "garanzia non si è potuta mettere alla prova: per rifarla, "
              "tools/reset_esercizio.sh M5-D03 e di nuovo in_classe.sh.")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NESSUNA = ("Non ancora: nessuna esecuzione in risposte/: eseguite i passi del "
           "README.")
RIFARE = ("Non ancora: una risposta manca o non va (qui sopra): per rifarla, "
          "tools/reset_esercizio.sh M5-D03 e di nuovo in_classe.sh.")
RIFAI = "rifate la demo"
USO = ("Uso: python3 controlla_garanzie.py [<spazio di lavoro>]\n"
       "     python3 controlla_garanzie.py --sessione <stream>\n")


class Precondizione(Exception):
    """Un file che non si legge: uscita 2."""


class Mancante(Exception):
    """Uno stream o un segreto che manca o non va: uscita 1."""


class Chiamata(NamedTuple):
    """Un tool_use della conversazione principale."""
    ident: str
    nome: str
    comando: str


class Esecuzione(NamedTuple):
    """Che cosa dice lo stream di una chiamata."""
    sessione: str
    elencate: List[str]
    chiamate: List[Chiamata]
    risultati: List[str]
    negati: List[str]
    testo: str
    turni: int
    token: int
    token_modelli: int
    millisecondi: int
    fermata: bool
    subagent: bool


def migliaia(numero: int) -> str:
    """Il numero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def si_no(vero: bool) -> str:
    return "sì" if vero else "no"


def in_secondi(millisecondi: float) -> str:
    """I secondi con la virgola, come gli altri controlli del modulo."""
    return ("%.1f" % (millisecondi / 1000)).replace(".", ",")


def quanti_turni(turni: int) -> str:
    """«1 turno», «2 turni»: il nome si accorda con il numero."""
    return "%d %s" % (turni, "turno" if turni == 1 else "turni")


def dice_i_turni(risultato: dict) -> bool:
    """Vero se un risultato dice quanti turni: un conto che manca non è zero, e
    la garanzia del comando si legge proprio sugli zero turni."""
    valore = risultato.get("num_turns")
    return isinstance(valore, (int, float)) and not isinstance(valore, bool)


def leggi_testo(rel: str) -> str:
    """Il testo di un file che c'è. Mancante se manca, Precondizione se non si
    legge."""
    if not os.path.lexists(rel):
        raise Mancante("manca %s: %s" % (rel, RIFAI))
    try:
        with open(rel, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (rel, exc.strerror or exc))


def leggi_eventi(rel: str) -> List[dict]:
    """Gli eventi di uno stream-json riuscito di claude -p."""
    testo = leggi_testo(rel)
    if not testo.strip():
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? %s"
                       % (rel, RIFAI))
    eventi = []
    # split("\n"), non splitlines(): un U+2028 dentro un testo JSON non chiude
    # la riga
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            raise Mancante("%s, riga %d: non è JSON; %s"
                           % (rel, numero, RIFAI))
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un oggetto JSON; %s"
                           % (rel, numero, RIFAI))
        eventi.append(evento)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato: la "
                       "chiamata si è interrotta? %s" % (rel, RIFAI))
    if ultimo.get("is_error") or ultimo.get("subtype", "success") != "success":
        raise Mancante("%s: claude ha restituito un errore; %s" % (rel, RIFAI))
    if not all(dice_i_turni(e) for e in eventi if e.get("type") == "result"):
        raise Mancante("%s: il risultato non dice num_turns, e un conto che "
                       "manca non è zero turni; %s" % (rel, RIFAI))
    return eventi


def blocchi(evento: dict) -> List[dict]:
    """I blocchi del contenuto di un messaggio."""
    messaggio = evento.get("message")
    contenuto = messaggio.get("content") if isinstance(messaggio, dict) \
        else None
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)]


def testo_di(contenuto: object) -> str:
    """Il testo del contenuto di un messaggio o di un risultato."""
    if isinstance(contenuto, str):
        return contenuto
    if isinstance(contenuto, list):
        return "\n".join(str(b.get("text", "")) for b in contenuto
                         if isinstance(b, dict))
    return ""


def fermata_in(evento: dict) -> bool:
    """Vero se un messaggio utente porta l'errore di un !`comando` fermato."""
    messaggio = evento.get("message")
    if evento.get("type") != "user" or not isinstance(messaggio, dict):
        return False
    return MESSAGGIO_FERMO in testo_di(messaggio.get("content"))


def chiamate_di(eventi: List[dict]) -> List[Chiamata]:
    """I tool_use della conversazione principale, una volta per id."""
    trovate: List[Chiamata] = []
    visti = set()
    for evento in eventi:
        if evento.get("type") != "assistant" \
                or evento.get("parent_tool_use_id"):
            continue
        for blocco in blocchi(evento):
            ident = str(blocco.get("id", ""))
            if blocco.get("type") != "tool_use" or (ident and ident in visti):
                continue
            visti.add(ident)
            ingresso = blocco.get("input")
            comando = ingresso.get("command", "") \
                if isinstance(ingresso, dict) else ""
            trovate.append(Chiamata(ident, str(blocco.get("name", "?")),
                                    str(comando)))
    return trovate


def risultati_di(eventi: List[dict]) -> List[str]:
    """I testi dei risultati degli strumenti."""
    testi = []
    for evento in eventi:
        if evento.get("type") == "user":
            testi += [testo_di(b.get("content")) for b in blocchi(evento)
                      if b.get("type") == "tool_result"]
    return testi


def subagent_in(eventi: List[dict]) -> bool:
    """Vero se lo stream mostra un subagent: l'evento task_started, o un
    messaggio con parent_tool_use_id."""
    return any((e.get("type") == "system"
                and e.get("subtype") == "task_started")
               or (e.get("type") == "user" and e.get("parent_tool_use_id"))
               for e in eventi)


def numero(valore: object) -> int:
    """Un contatore del risultato; 0 se non c'è."""
    if isinstance(valore, bool) or not isinstance(valore, (int, float)):
        return 0
    return int(valore)


def token_di(uso: object, chiavi: Tuple[str, ...]) -> int:
    return sum(numero(uso.get(c)) for c in chiavi) \
        if isinstance(uso, dict) else 0


def analizza(eventi: List[dict]) -> Esecuzione:
    """Che cosa dice lo stream: i contatori su ogni risultato, uno per
    segmento."""
    finali = [e for e in eventi if e.get("type") == "result"]
    negati = [str(v.get("tool_use_id", "")) for r in finali
              for v in (r.get("permission_denials") or [])
              if isinstance(v, dict)]
    init = next((e for e in eventi if e.get("type") == "system"
                 and e.get("subtype") == "init"), {})
    elencate = init.get("skills")
    testo = finali[-1].get("result")
    uso = ("input_tokens", "cache_creation_input_tokens",
           "cache_read_input_tokens", "output_tokens")
    modelli = finali[-1].get("modelUsage")
    return Esecuzione(
        sessione=str(finali[-1].get("session_id", "")),
        elencate=elencate if isinstance(elencate, list) else [],
        chiamate=chiamate_di(eventi), risultati=risultati_di(eventi),
        negati=negati, testo=testo if isinstance(testo, str) else "",
        turni=sum(numero(r.get("num_turns")) for r in finali),
        token=sum(token_di(r.get("usage"), uso) for r in finali),
        token_modelli=sum(token_di(d, (
            "inputTokens", "outputTokens", "cacheReadInputTokens",
            "cacheCreationInputTokens")) for d in (
                modelli.values() if isinstance(modelli, dict) else [])),
        millisecondi=sum(numero(r.get("duration_ms")) for r in finali),
        fermata=any(fermata_in(e) for e in eventi),
        subagent=subagent_in(eventi))


def trovato(segreto: str, testo: str) -> bool:
    """Il segreto nella risposta, senza guardare le maiuscole: una risposta che
    lo riscrive in maiuscolo l'ha visto."""
    return segreto.lower() in testo.lower()


def esito_conta(es: Esecuzione) -> str:
    """Che cosa è successo a bash conta.sh: eseguito (la sentinella è in un
    risultato), negato (la chiamata nei permission_denials) o non tentato."""
    if any(SENTINELLA in r for r in es.risultati):
        return "eseguito"
    if any(c.nome == "Bash" and RE_CONTA.search(c.comando)
           and c.ident in es.negati for c in es.chiamate):
        return "negato"
    return "non tentato"


def strumenti_testo(es: Esecuzione) -> str:
    """Gli strumenti chiamati, con il comando di Bash."""
    voci = ["%s (%s)" % (c.nome, c.comando) if c.comando else c.nome
            for c in es.chiamate]
    return ", ".join(voci) or "nessuno"


def giudica_elenco(skill: str, *esecuzioni: Esecuzione) -> Optional[str]:
    """Il perché, se in una delle esecuzioni la skill non era caricata."""
    if all(skill in es.elencate for es in esecuzioni):
        return None
    return "%s non è nell'elenco delle skill di ogni esecuzione" % skill


def giudica_codice(con: Esecuzione, senza: Esecuzione,
                   codice: str) -> Tuple[str, str]:
    """Il dato con !, contro il comando come testo."""
    if con.fermata:
        return NON_CONFERMATA, "con ! l'invocazione si è fermata"
    if con.chiamate:
        return NON_DISTINGUIBILE, ("con ! Claude ha chiamato uno strumento: "
                                   "il dato può venire da lì")
    if not trovato(codice, con.testo):
        return NON_CONFERMATA, ("con ! nessuno strumento, e il codice non è "
                                "nella risposta")
    if not senza.chiamate and trovato(codice, senza.testo):
        return NON_DISTINGUIBILE, ("senza ! il codice è arrivato senza "
                                   "strumenti: la coppia non mostra la "
                                   "differenza")
    return CONFERMATA, ("con ! il codice nella risposta, nessuno strumento; "
                        "senza !: %s, il codice %s" % (
                            strumenti_testo(senza),
                            "c'è" if trovato(codice, senza.testo)
                            else "non c'è"))


def giudica_comando(con: Esecuzione, senza: Esecuzione) -> Tuple[str, str]:
    """Il ! di un comando che non è di sola lettura, con il campo e senza."""
    if con.fermata:
        return NON_CONFERMATA, "con allowed-tools l'invocazione si è fermata"
    if con.chiamate:
        return NON_DISTINGUIBILE, ("con allowed-tools Claude ha chiamato uno "
                                   "strumento: il dato può venire da lì")
    if SENTINELLA not in con.testo:
        return NON_CONFERMATA, ("con allowed-tools la sentinella non è nella "
                                "risposta")
    if SENTINELLA in senza.testo or esito_conta(senza) == "eseguito":
        return NON_CONFERMATA, "senza allowed-tools il comando ha girato"
    if not senza.fermata:
        return NON_CONFERMATA, ("senza allowed-tools nello stream non c'è il "
                                "messaggio che ferma l'invocazione")
    if senza.turni:
        return NON_CONFERMATA, ("senza allowed-tools Claude ha lavorato lo "
                                "stesso: %s" % quanti_turni(senza.turni))
    return CONFERMATA, ("con allowed-tools la sentinella nella risposta, "
                        "nessuno strumento; senza, fermata con zero turni")


def giudica_permesso(con: Esecuzione, dopo: Esecuzione,
                     senza: Esecuzione) -> Tuple[str, str]:
    """allowed-tools nel turno, al messaggio dopo, e senza il campo."""
    if dopo.sessione != con.sessione:
        return NON_DISTINGUIBILE, ("il messaggio dopo non riprende la stessa "
                                   "sessione")
    nel_turno, poi, senza_campo = (esito_conta(con), esito_conta(dopo),
                                   esito_conta(senza))
    if nel_turno == "negato":
        return NON_CONFERMATA, ("con il campo il comando è negato nel turno "
                                "che invoca la skill")
    if nel_turno != "eseguito":
        return NON_DISTINGUIBILE, "con il campo Claude non ha eseguito niente"
    if poi == "eseguito":
        return NON_CONFERMATA, "al messaggio dopo il comando ha girato"
    if poi != "negato":
        return NON_DISTINGUIBILE, "al messaggio dopo Claude non ha riprovato"
    if senza_campo == "eseguito":
        return NON_CONFERMATA, "senza il campo il comando ha girato"
    if senza_campo != "negato":
        return NON_DISTINGUIBILE, "senza il campo Claude non ha tentato"
    return CONFERMATA, ("con il campo eseguito; al messaggio dopo negato; "
                        "senza il campo negato")


def giudica_parola(inline: Tuple[Esecuzione, Esecuzione],
                   fork: Tuple[Esecuzione, Esecuzione],
                   parola: str) -> Tuple[str, str]:
    """La parola detta nel primo turno, senza context: fork e con. Ogni
    braccio: (il primo turno, /prova-parola)."""
    if inline[0].sessione != inline[1].sessione \
            or fork[0].sessione != fork[1].sessione:
        return NON_DISTINGUIBILE, ("il secondo turno non riprende la stessa "
                                   "sessione")
    if trovato(parola, fork[1].testo):
        return NON_CONFERMATA, "con context: fork la parola è nella risposta"
    if not fork[1].subagent:
        return NON_DISTINGUIBILE, ("con context: fork lo stream non mostra il "
                                   "subagent")
    if inline[1].subagent:
        return NON_DISTINGUIBILE, ("senza context: fork lo stream mostra un "
                                   "subagent")
    if not trovato(parola, inline[1].testo):
        return NON_DISTINGUIBILE, ("senza context: fork la parola non torna: "
                                   "la coppia non mostra la differenza")
    return CONFERMATA, ("senza context: fork la parola torna; con context: "
                        "fork no, e lo stream mostra il subagent")


def numeri_delle_esecuzioni() -> List[int]:
    """I numeri delle esecuzioni di risposte/, in ordine."""
    numeri = set()
    for nome in os.listdir(CARTELLA):
        fatto = RE_NOME.match(nome)
        if fatto:
            numeri.add(int(fatto.group(1)))
    return sorted(numeri)


def avviso(messaggio: str) -> None:
    """Una risposta da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_garanzie.py: %s\n" % messaggio)


def leggi_segreto(nome: str) -> str:
    """Un segreto dello spazio di lavoro. Mancante se manca o è vuoto."""
    rel = "%s/%s" % (CARTELLA, nome)
    testo = leggi_testo(rel).strip()
    if not testo:
        raise Mancante("%s è vuoto: %s" % (rel, RIFAI))
    return testo


def leggi_tutto(numeri: List[int]) -> Optional[Dict[str, Esecuzione]]:
    """Le chiamate delle esecuzioni, per nome; None se una manca o non va (detto
    su STDERR)."""
    esecuzioni: Dict[str, Esecuzione] = {}
    mancanti = 0
    for n in numeri:
        for forma in STREAM:
            nome = forma % n
            try:
                esecuzioni[nome] = analizza(leggi_eventi(
                    "%s/%s.jsonl" % (CARTELLA, nome)))
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
    return None if mancanti else esecuzioni


def riga_consumo(es: Esecuzione) -> str:
    """Turni, token e secondi di una chiamata, sommati su ogni risultato."""
    return "turni %d; token %s (tutti i modelli %s); %s s" % (
        es.turni, migliaia(es.token), migliaia(es.token_modelli),
        in_secondi(es.millisecondi))


def risposta_breve(testo: str) -> str:
    risposta = " ".join(testo.split())
    return risposta[:119] + "…" if len(risposta) > 120 else risposta


def dati(nome: str, es: Esecuzione, cosa: str) -> None:
    """La riga dei dati di un'esecuzione. Arguments: il nome «coppia, braccio,
    n», l'esecuzione, ciò che guarda la sua coppia."""
    print("%s: risposta «%s»; %s; %s" % (nome, risposta_breve(es.testo), cosa,
                                         riga_consumo(es)))


def stampa_codice(es: Dict[str, Esecuzione], n: int, codice: str) -> None:
    for braccio in ("con", "senza"):
        una = es["codice-%s-%d" % (braccio, n)]
        dati("codice, %s, %d" % (braccio, n), una,
             "il codice nella risposta: %s; strumenti: %s" % (
                 si_no(trovato(codice, una.testo)), strumenti_testo(una)))


def stampa_comando(es: Dict[str, Esecuzione], n: int) -> None:
    for braccio in ("con", "senza"):
        una = es["comando-%s-%d" % (braccio, n)]
        dati("comando, %s, %d" % (braccio, n), una,
             "la sentinella nella risposta: %s; fermata: %s; strumenti: %s"
             % (si_no(SENTINELLA in una.testo), si_no(una.fermata),
                strumenti_testo(una)))


def stampa_permesso(es: Dict[str, Esecuzione], n: int) -> None:
    for nome, chiave in (("con", "permesso-con-%d"),
                         ("con, il messaggio dopo", "permesso-con-%d-dopo"),
                         ("senza", "permesso-senza-%d")):
        una = es[chiave % n]
        dati("permesso, %s, %d" % (nome, n), una,
             "bash conta.sh: %s" % esito_conta(una))


def stampa_parola(es: Dict[str, Esecuzione], n: int, parola: str) -> None:
    for braccio in ("inline", "fork"):
        una = es["parola-%s-%d" % (braccio, n)]
        dati("parola, %s, %d" % (braccio, n), una,
             "la parola nella risposta: %s; il subagent nello stream: %s"
             % (si_no(trovato(parola, una.testo)), si_no(una.subagent)))


def verdetti_di(es: Dict[str, Esecuzione], n: int, codice: str,
                parola: str) -> Dict[str, Tuple[str, str]]:
    """I verdetti di un'esecuzione, per coppia."""
    uno = {nome: es[forma % n] for nome, forma in (
        ("cc", "codice-con-%d"), ("cs", "codice-senza-%d"),
        ("oc", "comando-con-%d"), ("os", "comando-senza-%d"),
        ("pc", "permesso-con-%d"), ("pd", "permesso-con-%d-dopo"),
        ("ps", "permesso-senza-%d"), ("ia", "parola-inline-%d-prima"),
        ("ib", "parola-inline-%d"), ("fa", "parola-fork-%d-prima"),
        ("fb", "parola-fork-%d"))}
    esiti = {
        "codice": giudica_codice(uno["cc"], uno["cs"], codice),
        "comando": giudica_comando(uno["oc"], uno["os"]),
        "permesso": giudica_permesso(uno["pc"], uno["pd"], uno["ps"]),
        "parola": giudica_parola((uno["ia"], uno["ib"]), (uno["fa"], uno["fb"]),
                                 parola)}
    per_elenco = {"codice": (uno["cc"], uno["cs"]),
                  "comando": (uno["oc"], uno["os"]),
                  "permesso": (uno["pc"], uno["ps"]),
                  "parola": (uno["ib"], uno["fb"])}
    for coppia, bracci in per_elenco.items():
        perche = giudica_elenco(SKILL[coppia], *bracci)
        if perche:
            esiti[coppia] = (NON_DISTINGUIBILE, perche)
    return esiti


def riepilogo(etichetta: str, esiti: List[str]) -> str:
    """La riga «n su N» di una garanzia."""
    confermate = esiti.count(CONFERMATA)
    riga = "%s: %s %d su %d" % (etichetta, CONFERMATA, confermate, len(esiti))
    for altro in (NON_CONFERMATA, NON_DISTINGUIBILE):
        if altro in esiti:
            riga += "; %s %d" % (altro, esiti.count(altro))
    return riga


def stampa_consumo(es: Dict[str, Esecuzione]) -> None:
    """Il totale di tutte le chiamate, come dato."""
    print("\nCome dato, tutte le %d chiamate: turni %d; token %s; %s s." % (
        len(es), sum(e.turni for e in es.values()),
        migliaia(sum(e.token for e in es.values())),
        in_secondi(sum(e.millisecondi for e in es.values()))))


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa i dati
    e i verdetti e restituisce l'uscita 0 o 1."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    numeri = numeri_delle_esecuzioni()
    if not numeri:
        print(NESSUNA)
        return 1
    try:
        codice, parola = leggi_segreto("codice.txt"), leggi_segreto(
            "parola.txt")
    except Mancante as exc:
        avviso(str(exc))
        print(RIFARE)
        return 1
    es = leggi_tutto(numeri)
    if es is None:
        print(RIFARE)
        return 1
    esiti: Dict[str, List[str]] = {coppia: [] for coppia, _ in ETICHETTE}
    for n in numeri:
        stampa_codice(es, n, codice)
        stampa_comando(es, n)
        stampa_permesso(es, n)
        stampa_parola(es, n, parola)
        verdetti = verdetti_di(es, n, codice, parola)
        for coppia, etichetta in ETICHETTE:
            verdetto, perche = verdetti[coppia]
            esiti[coppia].append(verdetto)
            print("%s (%s, %d): %s (%s)" % (etichetta, coppia, n, verdetto,
                                            perche))
        print()
    for coppia, etichetta in ETICHETTE:
        print(riepilogo(etichetta, esiti[coppia]))
    stampa_consumo(es)
    tutti = [v for lista in esiti.values() for v in lista]
    if NON_CONFERMATA in tutti:
        print(SEGNALARE)
        return 1
    if NON_DISTINGUIBILE in tutti:
        print(NON_ANCORA)
        return 1
    print(TUTTE)
    return 0


def stampa_sessione(rel: str) -> int:
    """L'ID di sessione di uno stream: 0, oppure 1 se manca."""
    try:
        identita = analizza(leggi_eventi(rel)).sessione
    except Mancante as exc:
        avviso(str(exc))
        return 1
    if not identita:
        avviso("%s non ha un ID di sessione" % rel)
        return 1
    print(identita)
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


def esegui(argv: List[str]) -> int:
    """Gli argomenti e il controllo."""
    if argv[:1] == ["--sessione"]:
        if len(argv) != 2:
            return uso("--sessione vuole un file")
        return stampa_sessione(argv[1])
    sconosciute = [a for a in argv if a.startswith("-")]
    if sconosciute:
        return uso("opzione sconosciuta: %s" % sconosciute[0])
    if len(argv) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = argv[0] if argv else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    return controlla()


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    try:
        return esegui(argv)
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
