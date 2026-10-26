#!/usr/bin/env python3
"""kit.py -- gli attrezzi di misura delle esercitazioni del Modulo 2.

Li usa misura.sh; si possono usare anche da soli, dalla cartella
dell'esercizio. <cartella> è la cartella del prompt da misurare (quella
che contiene prompt/, dati/, rubrica.md e controlli.tsv): «.» se c'è un
prompt solo, altrimenti la sua famiglia (sviluppo, supporto, sistemi).

  componi   <cartella> <versione>  il prompt di prompt/<versione>.md, con
                                   ogni {{nome}} sostituito dal file
                                   dati/<nome>.<estensione>; prima della
                                   chiamata controlla anche controlli.tsv,
                                   la rubrica e il peso della consegna al
                                   giudice senza la risposta
  opzioni   <cartella> <versione> <modello> <effort>
                                   risposte/<versione>.opzioni: il modello
                                   e l'effort della risposta, l'impronta
                                   (sha256) del prompt e dei file di dati/;
                                   il confronto vi legge che cosa cambia
  estrai    <cartella> <versione>  il campo «result» di
                                   risposte/<versione>.json, scritto in
                                   risposte/<versione>.md
  controlla <cartella> <versione>  i controlli di controlli.tsv sulla
                                   risposta: controlli/<versione>.txt,
                                   da leggere; il confronto e la verifica
                                   li rifanno sulla risposta
  consegna  <cartella> <versione>  il testo che riceve il giudice: la
                                   rubrica (senza le pratiche), i dati, la
                                   risposta
  giudizio  <cartella> <versione>  il riepilogo di giudizi/<versione>.json
  stabilita <cartella> <versione>  il secondo giudizio della stessa
                                   risposta, <versione>-bis.json in
                                   giudizi/, e su quante affermazioni i
                                   due giudizi danno lo stesso esito
  confronta <cartella> <v1> <v2>   la pratica di <v2> (colonna «pratica» di
                                   registro.md) e il suo esito, dal
                                   confronto con <v1>: confermata, non
                                   confermata in questa misura o non
                                   decisa; poi controlli, giudizi e token,
                                   fianco a fianco
  pratiche  <cartella>             le pratiche, ognuna con la frase di
                                   Anthropic che mette alla prova

Il prompt composto e la consegna al giudice arrivano a claude -p come un
argomento solo: oltre i 100000 byte componi e consegna li rifiutano, con i
file da cui vengono e il loro peso.

Formati:
  rubrica.md     un'affermazione verificabile per riga, con la pratica che
                 la legge: «- **id** [pratica]: testo»; senza la pratica,
                 «- **id**: testo» (id in minuscolo, lettere e _)
  controlli.tsv  intestazione «tipo<TAB>valore<TAB>descrizione», con
                 «<TAB>pratica» in fondo se le righe la portano; poi una
                 riga per controllo, di tre campi o di quattro (il quarto,
                 la pratica, può restare vuoto); tipo: assente o presente
                 (valore: un'espressione regolare, senza distinzione tra
                 maiuscole e minuscole), parole_max, parole_min, righe_max
                 (valore: un numero); ogni descrizione una volta sola
  registro.md    una tabella con le colonne «versione» e «pratica» (e
                 «famiglia» se le famiglie sono più d'una): la pratica di
                 v0 è «partenza», quella di ogni altra versione una
                 dell'elenco di «pratiche»
La pratica di un criterio è chiarezza, contesto, ruolo o tag. Un BOM in
testa a rubrica.md, controlli.tsv o registro.md non cambia niente.

Uscita: 0 fatto; per controlla, ogni controllo superato; per confronta,
        qualunque sia l'esito della pratica ·
        1 per controlla, almeno un controllo non superato (un esito
        normale: v0 ne manca qualcuno); per gli altri comandi, un file di
        misura incompleto o con un errore (una risposta con is_error o con
        un usage non numerico, un giudizio senza structured_output) ·
        2 uso sbagliato, file assente o illeggibile, formato non valido,
        testo oltre il limite; per controlla, anche una risposta da
        rimisurare. Mai un traceback: un errore inatteso esce 2, con un
        messaggio di una riga.
"""
# Un file solo, oltre le ~800 righe, per scelta: il partecipante riceve un
# attrezzo solo in strumenti/, uguale byte per byte nelle due esercitazioni,
# e verifica.py dell'elemento lo carica per dire gli stessi esiti. La
# divisione naturale è pronta lungo le funzioni: la misura (fino a
# misura_stabile) e le pratiche con i loro esiti (da un_prompt_solo in giù).
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import textwrap
from typing import Dict, List, NoReturn, Optional, Sequence, Tuple

PLACEHOLDER = re.compile(r"\{\{([a-z][a-z0-9_]*)\}\}")
# «- **id** [pratica]: testo» o «- **id**: testo». Fra le quadre si accetta
# ogni testo: lo controlla pratica_criterio, così una pratica scritta male
# si segnala invece di sparire.
CLAIM = re.compile(
    r"^- \*\*([a-z][a-z0-9_]*)\*\*(?:\s*\[([^\]\n]*)\])?:\s+(\S.*)$")
VERSIONE = re.compile(r"v(?:0|[1-9][0-9]*)")  # con fullmatch
NUMERO = re.compile(r"[0-9]+")              # con fullmatch: cifre ASCII
TIPI = ("assente", "presente", "parole_max", "parole_min", "righe_max")
INTESTAZIONE = ["tipo", "valore", "descrizione"]
# I conteggi di usage che kit.py legge: i primi tre fanno l'entrata.
ENTRATA = ("input_tokens", "cache_creation_input_tokens",
           "cache_read_input_tokens")
RIGHE_RISPOSTA = 25   # quante righe della risposta stampa «estrai»
# Il prompt composto e la consegna viaggiano come un argomento solo di
# claude -p, e il sistema operativo ne limita la lunghezza (su Linux
# 128 KiB): oltre questo limite kit.py li ferma prima della chiamata.
LIMITE_BYTE = 100000
BIS = "-bis"          # il secondo giudizio di v0: giudizi/v0-bis.json
LARGHEZZA = 76        # le righe lunghe del confronto e delle pratiche
EFFORT = ("low", "medium", "high")   # dal più basso al più alto
CONFERMATA, NON_CONFERMATA, NON_DECISA = (
    "confermata", "non confermata in questa misura", "non decisa")
PARTENZA = "partenza"
BOM = chr(0xFEFF)     # il BOM che un editor può mettere in testa a un file
GUIDA = ("https://platform.claude.com/docs/it/build-with-claude/"
         "prompt-engineering/claude-prompting-best-practices")
BLOG = "https://claude.dev/blog/automating-eval-design-and-hillclimbing/"
GLOSSARIO = "https://platform.claude.com/docs/it/about-claude/glossary"
FRASE_BLOG = ("«Modelli più capaci e livelli di effort più alti di solito "
              "dovrebbero andare meglio in una valutazione. Se non "
              "succede, spesso a frenarli sono compiti ambigui o un "
              "valutatore mal calibrato.» (traduzione nostra)")
REGOLA_CRITERI = ("i criteri segnati [%s] in controlli.tsv e in rubrica.md "
                  "che hanno un esito in vA e in vB, senza le affermazioni "
                  "instabili, si contano nelle due versioni: confermata se "
                  "vB ne rispetta più di vA, non decisa se lo stesso "
                  "numero, non confermata in questa misura se meno")
SYSTEM_FISSO = ("la frase parla del system prompt, e misura.sh manda il "
                "vostro prompt come messaggio, con il system prompt fisso "
                "«Rispondi in italiano.»")
# Le pratiche: (id, la frase di Anthropic che mette alla prova, il link,
# come si decide l'esito). Le frasi in italiano sono quelle delle pagine
# italiane della documentazione; quella del blog è tradotta. Del glossario
# si cita la parte che la rimisura decide: «…» segna il taglio.
PRATICHE: Tuple[Tuple[str, str, str, str], ...] = (
    ("chiarezza", "«Sii specifico sul formato di output e sui vincoli che "
     "desideri.» «Più precisamente spieghi cosa vuoi, migliore sarà il "
     "risultato.»", GUIDA, REGOLA_CRITERI % "chiarezza"),
    ("contesto", "«Fornire il contesto o la motivazione alla base delle tue "
     "istruzioni, ad esempio spiegando a Claude perché un certo "
     "comportamento è importante, può dare a Claude più informazioni sui "
     "tuoi obiettivi e aiutarlo a fornire risposte più mirate.»", GUIDA,
     REGOLA_CRITERI % "contesto"),
    ("ruolo", "«Impostare un ruolo nel \"system prompt\" (prompt di "
     "sistema) focalizza il comportamento e il tono di Claude per il tuo "
     "caso d'uso.»", GUIDA, "sempre non decisa: " + SYSTEM_FISSO),
    ("tag", "«Racchiudere ogni tipo di contenuto nel proprio tag (ad "
     "esempio, <instructions>, <context>, <input>) riduce le "
     "interpretazioni errate.»", GUIDA, REGOLA_CRITERI % "tag"),
    ("effort", FRASE_BLOG, BLOG, "con lo stesso testo e lo stesso modello: "
     "confermata se la misura è più alta con l'effort più alto, non decisa "
     "se è la stessa, non confermata in questa misura se è più bassa; non "
     "decisa anche se con l'effort più basso è già al massimo"),
    ("modello", FRASE_BLOG, BLOG, "con lo stesso testo e lo stesso effort: "
     "il kit non sa quale dei due modelli sia «più capace», quindi stampa "
     "la misura e l'esito resta non decisa"),
    ("rimisura", "«… input identici potrebbero produrre output diversi tra "
     "diverse chiamate API.»", GLOSSARIO,
     "la stessa versione, misurata di nuovo: confermata se le due "
     "risposte sono diverse; se sono identiche, non decisa (un caso "
     "uguale non la smentisce)"),
)
TAG_CRITERI = ("chiarezza", "contesto", "ruolo", "tag")
SOLO_PROMPT_UNICO = ("rimisura",)   # solo dove il prompt è uno (M2-E01)
STESSO_TESTO = ("effort", "modello", "rimisura")   # il testo non cambia
NOMI = {"testo": "il testo del prompt", "dati": "i file di dati/",
        "modello": "il modello della risposta", "effort": "l'effort"}
INCERTI = {"testo": "il testo del prompt è cambiato",
           "dati": "i file di dati/ sono cambiati",
           "modello": "il modello della risposta è cambiato",
           "effort": "l'effort è cambiato"}


class Errore(Exception):
    """Un problema dei dati: l'uscita è il codice che porta (1 o 2)."""

    def __init__(self, messaggio: str, codice: int = 2) -> None:
        super().__init__(messaggio)
        self.codice = codice


def leggi(percorso: str) -> str:
    """Il testo di un file in UTF-8; Errore(2) se manca o non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        raise Errore("manca il file %s" % percorso)
    except (OSError, UnicodeDecodeError) as exc:
        raise Errore("non riesco a leggere %s (%s)" % (percorso, exc))


def senza_bom(testo: str) -> str:
    """Il testo senza il BOM in testa, se c'è: un file che l'editor ha
    salvato con il BOM dà lo stesso esito che senza."""
    return testo[len(BOM):] if testo.startswith(BOM) else testo


def scrivi(percorso: str, testo: str) -> None:
    """Scrive un file di testo in UTF-8, creando la cartella se serve;
    Errore(2) se non si scrive."""
    cartella = os.path.dirname(percorso)
    try:
        if cartella:
            os.makedirs(cartella, exist_ok=True)
        with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Errore("non riesco a scrivere %s (%s)" % (percorso, exc))


def controlla_versione(versione: str) -> None:
    """Rifiuta un nome di versione diverso da v0, v1, v2, ...: «v» e un
    numero senza zeri davanti, come in misura.sh."""
    if not VERSIONE.fullmatch(versione):
        raise Errore("versione «%s» non valida: si scrive v0, v1, v2, ..."
                     % versione)


def avvolgi(testo: str, rientro: str, seguito: Optional[str] = None) -> None:
    """Stampa un testo lungo su più righe, al massimo LARGHEZZA colonne."""
    print(textwrap.fill(testo, LARGHEZZA, initial_indent=rientro,
                        subsequent_indent=rientro if seguito is None
                        else seguito, break_long_words=False,
                        break_on_hyphens=False))


def plurale(n: int, uno: str, tanti: str) -> str:
    """«1 criterio», «2 criteri»."""
    return "%d %s" % (n, uno if n == 1 else tanti)


def dati(cartella: str) -> Dict[str, Tuple[str, str]]:
    """I file di <cartella>/dati, per nome senza estensione:
    {nome: (percorso, testo)}."""
    base = os.path.join(cartella, "dati")
    if not os.path.isdir(base):
        return {}
    try:
        nomi = sorted(os.listdir(base))
    except OSError as exc:
        raise Errore("non riesco a leggere la cartella %s (%s)" % (base, exc))
    trovati: Dict[str, Tuple[str, str]] = {}
    for nome in nomi:
        percorso = os.path.join(base, nome)
        if nome.startswith(".") or not os.path.isfile(percorso):
            continue
        radice = nome.split(".", 1)[0]
        if radice in trovati:
            raise Errore("in %s due file si chiamano «%s»: il segnaposto "
                         "{{%s}} sarebbe ambiguo" % (base, radice, radice))
        trovati[radice] = (percorso, leggi(percorso).rstrip("\n"))
    return trovati


def nel_limite(testo: str, cosa: str, fonti: List[Tuple[str, str]],
               rimedio: str) -> str:
    """Il testo, se in UTF-8 non supera LIMITE_BYTE; altrimenti Errore(2)
    con il peso del testo e di ogni sua fonte (percorso, testo)."""
    peso = len(testo.encode("utf-8"))
    if peso <= LIMITE_BYTE:
        return testo
    raise Errore("%s: %d byte, oltre il limite di %d byte (%s); %s" % (
        cosa, peso, LIMITE_BYTE, ", ".join(
            "%s %d byte" % (os.path.normpath(p), len(t.encode("utf-8")))
            for p, t in fonti), rimedio))


def componi(cartella: str, versione: str) -> str:
    """Il prompt di una versione con i dati al posto dei segnaposto; prima
    della chiamata a pagamento, controlla anche ciò che serve dopo."""
    controlla_versione(versione)
    percorso = os.path.join(cartella, "prompt", versione + ".md")
    testo = leggi(percorso)
    disponibili = dati(cartella)
    usati = sorted(set(PLACEHOLDER.findall(testo)))
    mancanti = [n for n in usati if n not in disponibili]
    if mancanti:
        raise Errore("il prompt %s usa %s, ma in %s/dati non c'è un file "
                     "con quel nome (ci sono: %s)" % (
                         versione, ", ".join("{{%s}}" % n for n in mancanti),
                         cartella, ", ".join(sorted(disponibili)) or "nessuno"))
    composto = PLACEHOLDER.sub(lambda m: disponibili[m.group(1)][1], testo)
    if not composto.strip():
        raise Errore("il prompt %s è vuoto" % versione)
    prompt = nel_limite(composto.rstrip("\n"),
                        "il prompt composto di %s è troppo lungo" % versione,
                        [(percorso, testo)] + [disponibili[n] for n in usati],
                        "accorciate i file di dati/")
    # Ciò che serve dopo la risposta si controlla prima di chiederla: le
    # righe di controlli.tsv, la rubrica, la consegna al giudice senza la
    # risposta (la rubrica e ogni file di dati/, anche quelli non usati).
    controlli(cartella)
    parti, fonti = consegna_fissa(cartella)
    nel_limite("\n".join(parti),
               "la consegna al giudice di %s è troppo lunga" % versione,
               fonti, "accorciate i file di dati/ o la rubrica")
    return prompt


def impronta(parti: Sequence[Tuple[str, str]]) -> str:
    """L'impronta sha256 di una serie di (nome, testo)."""
    h = hashlib.sha256()
    for nome, testo in parti:
        h.update(nome.encode("utf-8") + b"\0" + testo.encode("utf-8") + b"\0")
    return h.hexdigest()


def impronta_prompt(cartella: str, versione: str) -> Optional[str]:
    """L'impronta del prompt di una versione com'è adesso, None se il file
    manca o non si legge."""
    try:
        testo = leggi(os.path.join(cartella, "prompt", versione + ".md"))
    except Errore:
        return None
    return impronta([("prompt", testo)])


def scrivi_opzioni(cartella: str, versione: str, modello: str,
                   effort: str) -> None:
    """risposte/<v>.opzioni: il modello e l'effort della risposta, e le
    impronte del prompt e dei file di dati/ (una riga «chiave<TAB>valore»
    ciascuno)."""
    controlla_versione(versione)
    if not re.fullmatch(r"[a-z0-9.\[\]-]+", modello):
        raise Errore("modello «%s» non valido" % modello)
    if effort not in EFFORT:
        raise Errore("effort «%s»: si usa %s" % (effort, ", ".join(EFFORT)))
    prompt = impronta_prompt(cartella, versione)
    if prompt is None:
        raise Errore("manca il file %s" % os.path.join(
            cartella, "prompt", versione + ".md"))
    file_dati = impronta(sorted((n, t) for n, (_, t) in
                                dati(cartella).items()))
    scrivi(os.path.join(cartella, "risposte", versione + ".opzioni"),
           "modello\t%s\neffort\t%s\nprompt\t%s\ndati\t%s\n" % (
               modello, effort, prompt, file_dati))


def opzioni_di(cartella: str, versione: str) -> Dict[str, str]:
    """Le righe di risposte/<v>.opzioni, {} se il file non c'è (una misura
    fatta prima che il kit lo scrivesse); un effort fuori elenco non
    vale (non si sa)."""
    percorso = os.path.join(cartella, "risposte", versione + ".opzioni")
    if not os.path.isfile(percorso):
        return {}
    voci: Dict[str, str] = {}
    for riga in leggi(percorso).splitlines():
        chiave, _, valore = riga.partition("\t")
        if chiave.strip() and valore.strip():
            voci[chiave.strip()] = valore.strip()
    if voci.get("effort") not in EFFORT:
        voci.pop("effort", None)
    return voci


def json_di_claude(percorso: str) -> dict:
    """Il JSON di claude -p --output-format json; Errore(1) se è un errore."""
    try:
        doc = json.loads(leggi(percorso))
    except (ValueError, RecursionError) as exc:
        raise Errore("%s non è un JSON valido (%s)" % (percorso, exc), 1)
    if not isinstance(doc, dict) or doc.get("type") != "result":
        raise Errore("%s non è il JSON di claude -p" % percorso, 1)
    if doc.get("is_error"):
        raise Errore("%s contiene un errore di Claude Code: %s" % (
            percorso, str(doc.get("result"))[:200]), 1)
    return doc


def modelli_di(doc: dict) -> List[str]:
    """I modelli del campo modelUsage di un JSON di claude -p, in ordine."""
    uso = doc.get("modelUsage")
    return sorted(str(k) for k in uso) if isinstance(uso, dict) else []


def risposta(cartella: str, versione: str) -> str:
    """Il testo della risposta di una versione (risposte/<v>.json)."""
    doc = json_di_claude(os.path.join(cartella, "risposte", versione + ".json"))
    testo = doc.get("result")
    if not isinstance(testo, str) or not testo.strip():
        raise Errore("la risposta di %s è vuota" % versione, 1)
    return testo


def token(doc: dict, percorso: str) -> Tuple[int, int]:
    """(token in entrata, token in uscita) del campo usage del JSON di
    percorso; Errore(1) se un conteggio non è un numero intero."""
    uso = doc.get("usage") or {}
    if not isinstance(uso, dict):
        raise Errore("%s: usage non è un oggetto: misurate di nuovo la "
                     "versione" % percorso, 1)
    conti: Dict[str, int] = {}
    for chiave in ENTRATA + ("output_tokens",):
        valore = uso.get(chiave)
        if valore is None:
            conti[chiave] = 0
        elif isinstance(valore, int) and not isinstance(valore, bool):
            conti[chiave] = valore
        elif isinstance(valore, str) and NUMERO.fullmatch(valore):
            conti[chiave] = int(valore)
        else:
            raise Errore("%s: usage.%s non è un numero (%s): misurate di "
                         "nuovo la versione" % (percorso, chiave, json.dumps(
                             valore, ensure_ascii=False)[:40]), 1)
    return sum(conti[k] for k in ENTRATA), conti["output_tokens"]


def estrai(cartella: str, versione: str) -> None:
    """Scrive risposte/<v>.md e ne stampa l'inizio, con i token."""
    controlla_versione(versione)
    percorso = os.path.join(cartella, "risposte", versione + ".json")
    doc = json_di_claude(percorso)
    testo = risposta(cartella, versione)
    entrata, uscita = token(doc, percorso)
    scrivi(os.path.join(cartella, "risposte", versione + ".md"), testo + "\n")
    modelli = ", ".join(modelli_di(doc))
    print("Risposta %s (%s): %d token in entrata, %d in uscita"
          % (versione, modelli or "modello non indicato", entrata, uscita))
    righe = testo.strip("\n").split("\n")
    for riga in righe[:RIGHE_RISPOSTA]:
        print("  | " + riga)
    if len(righe) > RIGHE_RISPOSTA:
        print("  | […] (la risposta intera è in %s)" % os.path.join(
            cartella, "risposte", versione + ".md"))


def pratica_criterio(valore: str, dove: str) -> str:
    """La pratica di un criterio, "" se non c'è; Errore(2) se non è tra
    TAG_CRITERI."""
    valore = valore.strip()
    if valore and valore not in TAG_CRITERI:
        raise Errore("%s: la pratica «%s» non c'è; si usa %s" % (
            dove, valore, ", ".join(TAG_CRITERI)))
    return valore


def etichetta(pratica: str) -> str:
    """«[pratica] » davanti a un criterio che la porta, "" altrimenti."""
    return "[%s] " % pratica if pratica else ""


def rubrica(cartella: str) -> List[Tuple[str, str, str]]:
    """Le affermazioni di rubrica.md: [(id, testo, pratica)], almeno una;
    la pratica è "" dove la riga non la porta."""
    percorso = os.path.join(cartella, "rubrica.md")
    voci: List[Tuple[str, str, str]] = []
    visti = set()
    for n, riga in enumerate(senza_bom(leggi(percorso)).splitlines(),
                             start=1):
        m = CLAIM.match(riga.strip())
        if not m:
            continue
        if m.group(1) in visti:
            raise Errore("%s: l'id «%s» compare due volte"
                         % (percorso, m.group(1)))
        visti.add(m.group(1))
        voci.append((m.group(1), m.group(3).strip(), pratica_criterio(
            m.group(2) or "", "%s, riga %d" % (percorso, n))))
    if not voci:
        raise Errore("%s non contiene affermazioni nel formato "
                     "«- **id** [pratica]: testo»" % percorso)
    return voci


def controlli(cartella: str) -> List[Tuple[str, str, str, str]]:
    """Le righe di controlli.tsv: [(tipo, valore, descrizione, pratica)]."""
    percorso = os.path.join(cartella, "controlli.tsv")
    righe = senza_bom(leggi(percorso)).splitlines()
    testa = righe[0].rstrip("\r").split("\t") if righe else []
    if testa not in (INTESTAZIONE, INTESTAZIONE + ["pratica"]):
        raise Errore("%s: la prima riga deve essere «tipo<TAB>valore<TAB>"
                     "descrizione», con «<TAB>pratica» in fondo se le righe "
                     "la portano" % percorso)
    ammessi = (3,) if len(testa) == 3 else (3, 4)
    voci: List[Tuple[str, str, str, str]] = []
    for n, riga in enumerate(righe[1:], start=2):
        riga = riga.rstrip("\r")
        if not riga.strip():
            continue
        campi = riga.split("\t")
        if len(campi) not in ammessi or campi[0] not in TIPI:
            raise Errore("%s, riga %d: attesi tre campi%s, e un tipo tra %s"
                         % (percorso, n, "" if len(testa) == 3 else
                            " (o quattro, con la pratica)", ", ".join(TIPI)))
        tipo, valore, descrizione = campi[:3]
        if tipo in ("assente", "presente"):
            try:
                re.compile(valore)
            except (re.error, OverflowError, RecursionError) as exc:
                raise Errore("%s, riga %d: espressione non valida (%s)"
                             % (percorso, n, exc))
        elif not NUMERO.fullmatch(valore):
            raise Errore("%s, riga %d: «%s» vuole un numero" % (
                percorso, n, tipo))
        if any(descrizione == v[2] for v in voci):
            raise Errore("%s, riga %d: la descrizione «%s» c'è già" % (
                percorso, n, descrizione))
        voci.append((tipo, valore, descrizione, pratica_criterio(
            campi[3] if len(campi) == 4 else "", "%s, riga %d" % (
                percorso, n))))
    if not voci:
        raise Errore("%s non contiene controlli" % percorso)
    return voci


def esito_controllo(tipo: str, valore: str, testo: str) -> Tuple[bool, str]:
    """(superato, dettaglio) di un controllo sul testo della risposta. Il
    dettaglio sta su una riga: TAB e a capo del testo trovato diventano
    spazi."""
    if tipo in ("assente", "presente"):
        trovato = re.search(valore, testo, re.IGNORECASE)
        if tipo == "assente":
            return (trovato is None,
                    "trovato «%s»" % " ".join(trovato.group(0).split())
                    if trovato else "")
        return trovato is not None, "" if trovato else "non trovato"
    limite = int(valore)
    if tipo == "righe_max":
        n = len([r for r in testo.splitlines() if r.strip()])
        return n <= limite, "%d righe" % n
    n = len(testo.split())
    if tipo == "parole_max":
        return n <= limite, "%d parole" % n
    return n >= limite, "%d parole" % n


def esegui_controlli(cartella: str,
                     versione: str) -> List[Tuple[bool, str, str, str]]:
    """Ogni controllo di controlli.tsv sul testo di risposte/<v>.json:
    [(superato, descrizione, dettaglio, pratica)]. Lo stesso calcolo per
    controlla, che ne scrive controlli/<v>.txt, e per il confronto e la
    verifica, che quel file non lo leggono."""
    testo = risposta(cartella, versione)
    esiti: List[Tuple[bool, str, str, str]] = []
    for tipo, valore, descrizione, pratica in controlli(cartella):
        superato, dettaglio = esito_controllo(tipo, valore, testo)
        esiti.append((superato, descrizione, dettaglio, pratica))
    return esiti


def controlla(cartella: str, versione: str) -> bool:
    """Scrive controlli/<v>.txt (OK/KO per riga, poi il totale) e lo stampa,
    ogni controllo con la sua pratica: il file è da leggere, nessun esito
    lo rilegge. Returns: vero se ogni controllo è superato."""
    controlla_versione(versione)
    esiti = esegui_controlli(cartella, versione)
    superati = sum(1 for ok, _, _, _ in esiti if ok)
    righe = ["\t".join(["OK" if ok else "KO", descrizione, dettaglio])
             for ok, descrizione, dettaglio, _ in esiti]
    righe.append("totale\t%d/%d" % (superati, len(esiti)))
    scrivi(os.path.join(cartella, "controlli", versione + ".txt"),
           "\n".join(righe) + "\n")
    print("Controlli %s: %d %s su %d" % (
        versione, superati, "superato" if superati == 1 else "superati",
        len(esiti)))
    for ok, descrizione, dettaglio, pratica in esiti:
        print("  %s %s%s%s" % ("✓" if ok else "✗", etichetta(pratica),
                               descrizione,
                               " (%s)" % dettaglio if dettaglio else ""))
    return superati == len(esiti)


def consegna_fissa(cartella: str) -> Tuple[List[str], List[Tuple[str, str]]]:
    """Le righe della consegna al giudice prima della risposta (l'invito,
    la rubrica senza le pratiche, i dati) e le loro fonti, (percorso,
    testo)."""
    affermazioni = ["- %s: %s" % (i, t) for i, t, _ in rubrica(cartella)]
    fonti = [(os.path.join(cartella, "rubrica.md"), "\n".join(affermazioni))]
    parti = ["Valuta la risposta qui sotto con la rubrica: per ogni "
             "affermazione decidi se la risposta la rispetta.", "",
             "<rubrica>"] + affermazioni + ["</rubrica>", "", "<dati>"]
    for nome, (percorso, contenuto) in dati(cartella).items():
        parti += ["<%s>" % nome, contenuto, "</%s>" % nome]
        fonti.append((percorso, contenuto))
    return parti + ["</dati>", ""], fonti


def consegna(cartella: str, versione: str) -> str:
    """Il testo per il giudice: rubrica, dati e risposta, fra tag."""
    controlla_versione(versione)
    parti, fonti = consegna_fissa(cartella)
    testo = risposta(cartella, versione).strip("\n")
    fonti.append((os.path.join(cartella, "risposte", versione + ".md"), testo))
    return nel_limite("\n".join(parti + ["<risposta>", testo, "</risposta>"]),
                      "la consegna al giudice di %s è troppo lunga" % versione,
                      fonti, "accorciate i file di dati/ o la risposta")


def esiti_giudice(cartella: str, versione: str,
                  suffisso: str = "") -> Dict[str, Tuple[Optional[bool], str]]:
    """{id: (rispettato, motivo)} di giudizi/<v><suffisso>.json, per ogni
    id della rubrica; rispettato è None dove il giudice non l'ha valutato."""
    percorso = os.path.join(cartella, "giudizi", versione + suffisso + ".json")
    doc = json_di_claude(percorso)
    uscita = doc.get("structured_output")
    if not isinstance(uscita, dict) or not isinstance(
            uscita.get("criteri"), list):
        raise Errore("%s non contiene il giudizio strutturato "
                     "(structured_output.criteri)" % percorso, 1)
    attesi = [i for i, _, _ in rubrica(cartella)]
    trovati: Dict[str, Tuple[Optional[bool], str]] = {}
    for voce in uscita["criteri"]:
        if not isinstance(voce, dict):
            continue
        ident = voce.get("id")
        if ident in attesi and ident not in trovati and isinstance(
                voce.get("rispettato"), bool):
            trovati[ident] = (voce["rispettato"], str(voce.get("motivo", "")))
    return {i: trovati.get(i, (None, "non valutato dal giudice"))
            for i in attesi}


def stampa_giudizio(cartella: str, versione: str, suffisso: str = "") -> None:
    """Il riepilogo di un giudizio: quante affermazioni, e ognuna con la
    sua pratica."""
    controlla_versione(versione)
    doc = json_di_claude(os.path.join(cartella, "giudizi",
                                      versione + suffisso + ".json"))
    esiti = esiti_giudice(cartella, versione, suffisso)
    pratiche = {i: p for i, _, p in rubrica(cartella)}
    rispettate = sum(1 for ok, _ in esiti.values() if ok)
    print("Giudizio %s%s (%s): %d %s su %d" % (
        versione, ", la seconda volta" if suffisso else "",
        ", ".join(modelli_di(doc)) or "modello non indicato", rispettate,
        "affermazione rispettata" if rispettate == 1
        else "affermazioni rispettate", len(esiti)))
    for ident, (ok, motivo) in esiti.items():
        print("  %s %s%s: %s" % ("✓" if ok else "✗",
                                 etichetta(pratiche.get(ident, "")), ident,
                                 motivo))
    if not suffisso:
        avviso_stesso_modello(cartella, versione)


def stesso_esito(uno: Optional[bool], due: Optional[bool]) -> bool:
    """Vero se i due giudizi hanno valutato l'affermazione allo stesso
    modo (una non valutata non è mai lo stesso esito)."""
    return uno is not None and uno == due


def instabili_di(cartella: str, versione: str) -> List[str]:
    """Gli id su cui giudizi/<v>.json e giudizi/<v>-bis.json non danno lo
    stesso esito."""
    uno = esiti_giudice(cartella, versione)
    due = esiti_giudice(cartella, versione, BIS)
    return [i for i in uno if not stesso_esito(uno[i][0], due[i][0])]


def instabili(cartella: str) -> Optional[List[str]]:
    """Le affermazioni instabili di v0, None se v0 non ha il secondo
    giudizio: allora la prova del giudice manca."""
    if not os.path.isfile(os.path.join(cartella, "giudizi",
                                       "v0" + BIS + ".json")):
        return None
    return instabili_di(cartella, "v0")


def stampa_stabilita(cartella: str, versione: str) -> None:
    """Il secondo giudizio della stessa risposta, e la riga della prova
    del giudice: su quante affermazioni i due giudizi concordano."""
    stampa_giudizio(cartella, versione, BIS)
    tutte = len(rubrica(cartella))
    diverse = instabili_di(cartella, versione)
    print("Giudice su %s: stesso esito due volte su %d %s di %d; "
          "instabili: %s." % (versione, tutte - len(diverse),
                              "affermazione" if tutte - len(diverse) == 1
                              else "affermazioni", tutte,
                              ", ".join(diverse) or "nessuna"))
    if diverse:
        avvolgi("Un'affermazione instabile non è una prova: in %s conta come "
                "non rispettata, e negli esiti delle pratiche non conta."
                % versione, "  ")


def esiti_controlli(cartella: str, versione: str) -> Dict[str, bool]:
    """{descrizione: superato}: i controlli rifatti sulla risposta
    (esegui_controlli), mai letti da controlli/<v>.txt."""
    return {descrizione: superato for superato, descrizione, _, _
            in esegui_controlli(cartella, versione)}


def segno(valore: Optional[bool]) -> str:
    """✓, ✗ o — (non misurato)."""
    if valore is None:
        return "—"
    return "✓" if valore else "✗"


def misura_completa(cartella: str, versione: str) -> None:
    """Errore(2) se della versione manca la risposta o il giudizio: una
    misura fermata a metà, da rifare. I controlli non si cercano in
    controlli/: si rifanno sulla risposta."""
    for nome in (os.path.join("risposte", versione + ".json"),
                 os.path.join("giudizi", versione + ".json")):
        percorso = os.path.normpath(os.path.join(cartella, nome))
        if not os.path.isfile(percorso):
            raise Errore("la misura di %s è incompleta (manca %s): misurate "
                         "di nuovo %s (./misura.sh%s %s)" % (
                             versione, percorso, versione,
                             "" if cartella == "." else " " + cartella,
                             versione))


def misura_stabile(cartella: str, versione: str,
                   instab: List[str]) -> Tuple[int, int]:
    """(misura, massimo): i controlli superati più le affermazioni
    rispettate, senza le instabili."""
    esiti_c = esiti_controlli(cartella, versione)
    esiti_g = esiti_giudice(cartella, versione)
    stabili = [i for i in esiti_g if i not in instab]
    return (sum(esiti_c.values()) + sum(1 for i in stabili
                                        if esiti_g[i][0]),
            len(esiti_c) + len(stabili))


def un_prompt_solo(cartella: str) -> bool:
    """Vero dove l'esercizio ha un prompt solo (M2-E01): la cartella ha
    insieme registro.md e prompt/."""
    return (os.path.isfile(os.path.join(cartella, "registro.md"))
            and os.path.isdir(os.path.join(cartella, "prompt")))


def percorso_registro(cartella: str) -> Tuple[str, Optional[str]]:
    """(il percorso di registro.md, la famiglia o None): il registro sta
    nella cartella del prompt se il prompt è uno, sopra la famiglia se le
    famiglie sono più d'una (M2-E02)."""
    if os.path.isfile(os.path.join(cartella, "registro.md")):
        return os.path.join(cartella, "registro.md"), None
    assoluta = os.path.abspath(cartella)
    return (os.path.join(os.path.dirname(assoluta), "registro.md"),
            os.path.basename(assoluta))


def tabella(testo: str) -> List[Dict[str, str]]:
    """Le righe della prima tabella di un testo markdown, {colonna:
    valore}; l'intestazione in minuscolo, la riga di trattini saltata."""
    intestazione: Optional[List[str]] = None
    righe: List[Dict[str, str]] = []
    for riga in testo.splitlines():
        riga = riga.strip()
        if not riga.startswith("|"):
            if intestazione is not None:
                break
            continue
        celle = [c.strip() for c in riga.strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in celle if c):
            continue
        if intestazione is None:
            intestazione = [c.lower() for c in celle]
        else:
            righe.append(dict(zip(intestazione, celle)))
    return righe


def riga_registro(cartella: str,
                  versione: str) -> Tuple[Optional[Dict[str, str]], str]:
    """(la riga di registro.md della versione, "") o (None, il
    problema)."""
    percorso, famiglia = percorso_registro(cartella)
    if not os.path.isfile(percorso):
        return None, "manca registro.md"
    for campi in tabella(senza_bom(leggi(percorso))):
        if campi.get("versione") == versione and (
                famiglia is None or campi.get("famiglia") == famiglia):
            return campi, ""
    return None, "registro.md non ha la riga di %s%s" % (
        versione, " di " + famiglia if famiglia else "")


def pratiche_ammesse(cartella: str, versione: str) -> List[str]:
    """Le pratiche che una versione può avere: «partenza» per v0, le altre
    dell'elenco (rimisura solo dove il prompt è uno)."""
    if versione == "v0":
        return [PARTENZA]
    unico = un_prompt_solo(cartella)
    return [p for p, _, _, _ in PRATICHE
            if unico or p not in SOLO_PROMPT_UNICO]


def pratica_di(cartella: str, versione: str) -> Tuple[Optional[str], str]:
    """(la pratica della versione in registro.md, "") o (None, il
    problema)."""
    campi, problema = riga_registro(cartella, versione)
    if campi is None:
        return None, problema
    if "pratica" not in campi:
        return None, "registro.md non ha la colonna «pratica»"
    valore = campi["pratica"].strip().strip("`'\"«»*").strip().lower()
    if not valore or valore in ("…", "..."):
        return None, "in registro.md la pratica di %s è da scrivere" % (
            versione)
    ammesse = pratiche_ammesse(cartella, versione)
    if valore not in ammesse:
        return None, "in registro.md la pratica di %s è «%s»: si scrive %s" % (
            versione, valore, " o ".join(ammesse) if len(ammesse) == 1
            else "una di " + ", ".join(ammesse))
    return valore, ""


def diversi(prima: Optional[str], dopo: Optional[str]) -> Optional[bool]:
    """True se i due valori sono diversi, False se uguali, None se ne
    manca uno."""
    if prima is None or dopo is None:
        return None
    return prima != dopo


def cambi(cartella: str, prima: str,
          dopo: str) -> Dict[str, Tuple[Optional[bool], str, str]]:
    """Che cosa cambia da prima a dopo: per testo, dati, modello ed effort
    (cambia: True, False o None se non si sa; valore prima; valore dopo).
    Il testo e i dati dalle impronte di risposte/<v>.opzioni (il testo,
    dove manca, dal prompt attuale); il modello dal modelUsage della
    risposta."""
    op, od = opzioni_di(cartella, prima), opzioni_di(cartella, dopo)
    modelli = [", ".join(modelli_di(json_di_claude(os.path.join(
        cartella, "risposte", v + ".json")))) or o.get("modello", "")
        for v, o in ((prima, op), (dopo, od))]
    testi = [o.get("prompt") or impronta_prompt(cartella, v)
             for v, o in ((prima, op), (dopo, od))]
    return {"testo": (diversi(testi[0], testi[1]), "", ""),
            "dati": (diversi(op.get("dati"), od.get("dati")), "", ""),
            "modello": (diversi(modelli[0] or None, modelli[1] or None),
                        modelli[0], modelli[1]),
            "effort": (diversi(op.get("effort"), od.get("effort")),
                       op.get("effort", ""), od.get("effort", ""))}


def coerenza(pratica: str, c: Dict[str, Tuple[Optional[bool], str, str]],
             prima: str, dopo: str) -> str:
    """Il motivo per cui il confronto da prima a dopo non mette alla prova
    la pratica (due cose cambiate insieme, o nessuna), "" se la mette."""
    attesi = {"dati": False, "testo": pratica not in STESSO_TESTO,
              "modello": pratica == "modello", "effort": pratica == "effort"}
    for chiave in ("dati", "testo", "modello", "effort"):
        cambia, a, b = c[chiave]
        atteso = attesi[chiave]
        if cambia is None:
            if atteso or chiave == "testo" or pratica == "rimisura":
                return "non si sa se %s: %s" % (
                    INCERTI[chiave], "manca prompt/%s.md o prompt/%s.md" % (
                        prima, dopo) if chiave == "testo" else
                    "manca risposte/%s.opzioni o risposte/%s.opzioni "
                    "(misurate di nuovo)" % (prima, dopo))
            continue
        if cambia and not atteso:
            if chiave == "testo":
                return ("con «%s» il testo del prompt resta lo stesso, e da "
                        "%s a %s è cambiato" % (pratica, prima, dopo))
            if chiave == "dati":
                return "sono cambiati anche i file di dati/: due cose insieme"
            return "è cambiato anche %s%s: due cose insieme" % (
                NOMI[chiave], " (%s → %s)" % (a, b) if a and b else "")
        if atteso and not cambia:
            if chiave == "testo":
                return ("il testo del prompt di %s è uguale a quello di %s: "
                        "la pratica non è stata applicata" % (dopo, prima))
            return "%s è lo stesso (%s): la pratica non è stata applicata" % (
                NOMI[chiave], a)
    return ""


def coppie_criteri(cartella: str, prima: str, dopo: str, pratica: str,
                   instab: List[str]) -> Tuple[List[Tuple[str, bool, bool]],
                                               int, int, int]:
    """I criteri segnati con la pratica che hanno un esito in prima e in
    dopo, senza le affermazioni instabili: ([(nome, rispettato prima,
    rispettato dopo)], quanti sono segnati, quante instabili, quanti
    senza un esito in una delle due versioni)."""
    segnati = [d for _, _, d, p in controlli(cartella) if p == pratica]
    cp = esiti_controlli(cartella, prima)
    cd = esiti_controlli(cartella, dopo)
    coppie = [(d, cp[d], cd[d]) for d in segnati if d in cp and d in cd]
    gp, gd = esiti_giudice(cartella, prima), esiti_giudice(cartella, dopo)
    segnate = [i for i, _, p in rubrica(cartella) if p == pratica]
    instabili_segnate = len([i for i in segnate if i in instab])
    coppie += [(i, bool(gp[i][0]), bool(gd[i][0])) for i in segnate
               if i not in instab and gp[i][0] is not None
               and gd[i][0] is not None]
    tutti = len(segnati) + len(segnate)
    return (coppie, tutti, instabili_segnate,
            tutti - instabili_segnate - len(coppie))


def esito_criteri(cartella: str, prima: str, dopo: str, pratica: str,
                  instab: List[str]) -> Tuple[str, str]:
    """(esito, perché) di una pratica dai criteri segnati con il suo nome,
    contati in prima e in dopo (coppie_criteri): confermata se dopo ne
    rispetta più di prima, non decisa se lo stesso numero (la coppia non
    lo dice), non confermata in questa misura se meno. Il perché dà i due
    conteggi, poi i criteri che dopo non rispetta."""
    coppie, tutti, escluse, senza_esito = coppie_criteri(
        cartella, prima, dopo, pratica, instab)
    instabili_note: List[str] = []
    if escluse:
        instabili_note.append("senza %s" % plurale(
            escluse, "affermazione instabile", "affermazioni instabili"))
    if not coppie:
        if not tutti:
            return NON_DECISA, ("nessun criterio è segnato [%s] in "
                                "controlli.tsv o in rubrica.md" % pratica)
        if escluse == tutti:
            return NON_DECISA, ("i criteri segnati [%s] sono solo "
                                "affermazioni instabili: il loro esito non è "
                                "una prova" % pratica)
        return NON_DECISA, "; ".join([
            "nessun criterio segnato [%s] ha un esito in %s e in %s" % (
                pratica, prima, dopo)] + instabili_note)
    n_a = sum(1 for _, a, _ in coppie if a)
    n_b = sum(1 for _, _, b in coppie if b)
    parti = ["criteri segnati [%s] rispettati: %d su %d in %s, %d su %d in "
             "%s" % (pratica, n_a, len(coppie), prima, n_b, len(coppie),
                     dopo)]
    if n_b == n_a:
        parti.append("lo stesso numero: questa coppia non lo dice")
    parti += instabili_note
    if senza_esito:
        parti.append("%s %s senza esito in %s o in %s" % (
            "escluso" if senza_esito == 1 else "esclusi",
            plurale(senza_esito, "criterio", "criteri"), prima, dopo))
    no = [nome for nome, _, b in coppie if not b]
    if no:
        parti.append("non rispettati in %s: %s" % (dopo, ", ".join(no)))
    dettaglio = "; ".join(parti)
    if n_b > n_a:
        return CONFERMATA, dettaglio
    if n_b == n_a:
        return NON_DECISA, dettaglio
    return NON_CONFERMATA, dettaglio


def esito_effort(cartella: str, prima: str, dopo: str,
                 efforts: Tuple[str, str],
                 instab: List[str]) -> Tuple[str, str]:
    """(esito, perché) della pratica effort: con l'effort più alto la
    misura è più alta (confermata), la stessa (non decisa: la coppia non
    lo dice) o più bassa (non confermata in questa misura)? Non decisa
    anche se con l'effort più basso la misura è già al massimo."""
    a, massimo = misura_stabile(cartella, prima, instab)
    b, _ = misura_stabile(cartella, dopo, instab)
    basso, alto = sorted([(EFFORT.index(efforts[0]), efforts[0], prima, a),
                          (EFFORT.index(efforts[1]), efforts[1], dopo, b)])
    dettaglio = ("misura %d con effort %s (%s), %d con effort %s (%s), su %d"
                 % (basso[3], basso[1], basso[2], alto[3], alto[1], alto[2],
                    massimo))
    if basso[3] >= massimo:
        return NON_DECISA, ("con l'effort più basso la misura è già al "
                            "massimo, non c'è margine: %s" % dettaglio)
    if alto[3] > basso[3]:
        return CONFERMATA, dettaglio
    if alto[3] == basso[3]:
        return NON_DECISA, ("%s; la stessa misura: questa coppia non lo dice"
                            % dettaglio)
    return NON_CONFERMATA, ("%s; Anthropic: se non succede, spesso a frenare "
                            "sono compiti ambigui o un valutatore mal "
                            "calibrato (traduzione nostra)" % dettaglio)


def esito_rimisura(cartella: str, prima: str, dopo: str,
                   instab: List[str]) -> Tuple[str, str]:
    """(esito, perché) della pratica rimisura: la stessa versione,
    misurata di nuovo, ha dato una risposta diversa?"""
    tp, td = risposta(cartella, prima), risposta(cartella, dopo)
    a, massimo = misura_stabile(cartella, prima, instab)
    b, _ = misura_stabile(cartella, dopo, instab)
    dettaglio = "parole %d → %d, misura %d → %d su %d" % (
        len(tp.split()), len(td.split()), a, b, massimo)
    if tp == td:
        return NON_DECISA, ("le due risposte sono identiche (%s): un caso "
                            "uguale non smentisce la frase" % dettaglio)
    return CONFERMATA, "le due risposte sono diverse (%s)" % dettaglio


def esito_pratica(cartella: str, prima: str, dopo: str,
                  instab: List[str]) -> Tuple[Optional[str], str, str]:
    """(la pratica di dopo, l'esito, il perché) del confronto da prima a
    dopo: l'esito è confermata, non confermata in questa misura o non
    decisa."""
    pratica, problema = pratica_di(cartella, dopo)
    if pratica is None:
        return None, NON_DECISA, problema
    if pratica == PARTENZA:
        return pratica, NON_DECISA, "%s è la partenza" % dopo
    c = cambi(cartella, prima, dopo)
    problema = coerenza(pratica, c, prima, dopo)
    if problema:
        return pratica, NON_DECISA, problema
    if pratica == "ruolo":
        return pratica, NON_DECISA, SYSTEM_FISSO
    if pratica == "modello":
        a, massimo = misura_stabile(cartella, prima, instab)
        b, _ = misura_stabile(cartella, dopo, instab)
        return pratica, NON_DECISA, (
            "il kit non sa quale dei due modelli sia «più capace»: la misura "
            "passa da %d a %d su %d (%s → %s)" % (
                a, b, massimo, c["modello"][1], c["modello"][2]))
    if pratica == "effort":
        esito, perche = esito_effort(cartella, prima, dopo, (
            c["effort"][1], c["effort"][2]), instab)
    elif pratica == "rimisura":
        esito, perche = esito_rimisura(cartella, prima, dopo, instab)
    else:
        esito, perche = esito_criteri(cartella, prima, dopo, pratica, instab)
    return pratica, esito, perche


def voce_pratica(pratica: str) -> Tuple[str, str, str, str]:
    """La voce di PRATICHE con quel nome."""
    for voce in PRATICHE:
        if voce[0] == pratica:
            return voce
    raise Errore("pratica «%s» sconosciuta" % pratica)


def stampa_pratica(versione: str, pratica: Optional[str]) -> None:
    """La pratica di una versione, con la frase di Anthropic e il link."""
    if pratica is None or pratica == PARTENZA:
        print("  pratica di %s: %s" % (versione, pratica or "non indicata"))
        return
    _, frase, link, _ = voce_pratica(pratica)
    avvolgi("pratica di %s: %s — Anthropic: %s" % (versione, pratica, frase),
            "  ", "    ")
    print("    " + link)


def avviso_stesso_modello(cartella: str, versione: str) -> None:
    """Un avviso se la risposta e il giudizio di una versione vengono
    dallo stesso modello (il modelUsage dei due JSON). Senza i due JSON
    l'avviso non si può dare: li segnalano già i comandi che li leggono."""
    try:
        r = modelli_di(json_di_claude(os.path.join(
            cartella, "risposte", versione + ".json")))
        g = modelli_di(json_di_claude(os.path.join(
            cartella, "giudizi", versione + ".json")))
    except Errore:
        return
    comuni = sorted(set(r) & set(g))
    if comuni:
        avvolgi("attenzione: in %s la risposta e il giudizio vengono dallo "
                "stesso modello (%s); Anthropic: il modello giudice «non "
                "dovrebbe essere il modello che state valutando» (traduzione "
                "nostra)" % (versione, ", ".join(comuni)), "  ", "    ")


def confronta(cartella: str, prima: str, dopo: str) -> None:
    """La pratica di dopo e il suo esito, poi controlli, giudizi e token
    delle due versioni fianco a fianco; mai una misura fermata a metà."""
    for v in (prima, dopo):
        controlla_versione(v)
        misura_completa(cartella, v)
    prova = instabili(cartella)
    instab = prova or []
    pratiche_c = {d: p for _, _, d, p in controlli(cartella)}
    pratiche_g = {i: p for i, _, p in rubrica(cartella)}
    cp, cd = esiti_controlli(cartella, prima), esiti_controlli(cartella, dopo)
    gp, gd = esiti_giudice(cartella, prima), esiti_giudice(cartella, dopo)
    pratica, esito, perche = esito_pratica(cartella, prima, dopo, instab)

    def conta(esiti: Dict[str, Tuple[Optional[bool], str]], versione: str,
              ident: str) -> bool:
        # in v0 un'affermazione instabile conta come non rispettata
        return bool(esiti[ident][0]) and not (versione == "v0"
                                              and ident in instab)

    print("Confronto %s → %s%s" % (prima, dopo, "" if cartella == "." else
                                   " (%s)" % cartella))
    stampa_pratica(dopo, pratica)
    print("  controlli:")
    for descr in list(dict.fromkeys(list(cp) + list(cd))):
        print("    %s  %s  %s%s" % (segno(cp.get(descr)), segno(cd.get(descr)),
                                    etichetta(pratiche_c.get(descr, "")),
                                    descr))
    print("  giudice:")
    for ident in gp:
        print("    %s  %s  %s%s%s" % (
            segno(conta(gp, prima, ident)), segno(conta(gd, dopo, ident)),
            etichetta(pratiche_g.get(ident, "")), ident,
            " (instabile)" if ident in instab else ""))
    avvolgi("esito della pratica: %s (%s)" % (esito, perche), "  ", "    ")
    if prova is None:
        avvolgi("attenzione: v0 ha un giudizio solo, quindi la prova del "
                "giudice manca (./misura.sh%s v0 la rifà)" % (
                    "" if cartella == "." else " " + cartella), "  ", "    ")
    print("  totali: controlli %d/%d → %d/%d; giudice %d → %d su %d" % (
        sum(cp.values()), len(cp), sum(cd.values()), len(cd),
        sum(conta(gp, prima, i) for i in gp),
        sum(conta(gd, dopo, i) for i in gd), len(gp)))
    pp = os.path.join(cartella, "risposte", prima + ".json")
    pd = os.path.join(cartella, "risposte", dopo + ".json")
    ep, up = token(json_di_claude(pp), pp)
    ed, ud = token(json_di_claude(pd), pd)
    print("  token: in entrata %d → %d, in uscita %d → %d" % (ep, ed, up, ud))
    for v in (prima, dopo):
        avviso_stesso_modello(cartella, v)


def stampa_pratiche(cartella: str) -> None:
    """Le pratiche ammesse qui, ognuna con la frase di Anthropic, il link e
    come se ne decide l'esito."""
    ammesse = pratiche_ammesse(cartella, "v1")
    avvolgi("Le pratiche: una per versione. Scrivetela nella colonna "
            "«pratica» di registro.md prima di misurare la versione; v0 è "
            "la «partenza».", "")
    avvolgi("Poi ./misura.sh --confronta [cartella] vA vB dice l'esito "
            "della pratica di vB: confermata, non confermata in questa "
            "misura o non decisa.", "")
    for ident, frase, link, regola in PRATICHE:
        if ident not in ammesse:
            continue
        print("")
        print(ident)
        avvolgi("Anthropic: " + frase, "  ")
        print("  " + link)
        avvolgi("esito: " + regola, "  ")


def errore(messaggio: str, codice: int) -> NoReturn:
    """Il messaggio su STDERR e l'uscita."""
    sys.stderr.write("kit.py: %s\n" % messaggio)
    sys.exit(codice)


def main(argv: List[str]) -> int:
    comandi = {"componi": 2, "opzioni": 4, "estrai": 2, "controlla": 2,
               "consegna": 2, "giudizio": 2, "stabilita": 2,
               "confronta": 3, "pratiche": 1}
    if not argv or argv[0] not in comandi or len(argv) != comandi[argv[0]] + 1:
        sys.stderr.write(__doc__)
        return 2
    comando, cartella = argv[0], argv[1]
    if not os.path.isdir(cartella):
        errore("la cartella «%s» non esiste" % cartella, 2)
    try:
        if comando == "componi":
            print(componi(cartella, argv[2]))
        elif comando == "opzioni":
            scrivi_opzioni(cartella, argv[2], argv[3], argv[4])
        elif comando == "estrai":
            estrai(cartella, argv[2])
        elif comando == "controlla":
            return 0 if controlla(cartella, argv[2]) else 1
        elif comando == "consegna":
            print(consegna(cartella, argv[2]))
        elif comando == "giudizio":
            stampa_giudizio(cartella, argv[2])
        elif comando == "stabilita":
            stampa_stabilita(cartella, argv[2])
        elif comando == "pratiche":
            stampa_pratiche(cartella)
        else:
            confronta(cartella, argv[2], argv[3])
    except Errore as exc:
        # Per controlla l'uscita 1 dice «un controllo non superato»: ogni
        # altro problema, lì, esce 2.
        errore(str(exc), 2 if comando == "controlla" else exc.codice)
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        errore("errore inatteso (%s: %s): avvisate il docente" % (
            type(exc).__name__, " ".join(str(exc).split())), 2)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
