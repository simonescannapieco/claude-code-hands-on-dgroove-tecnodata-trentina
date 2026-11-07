"""controlla_sessione.py -- le garanzie della demo M6-D04 «Una modifica a
sessione avviata, e dopo /compact» alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente), ciò che
in_classe.sh lascia in risposte/, tre sessioni per esecuzione n, ognuna un
solo processo di claude -p con --input-format stream-json (sessione.py):
  compact-<n>  1 domanda; 2 CLAUDE.md riscritto da fuori; 3 domanda;
               4 /compact; 5 domanda
  clear-<n>    gli stessi passi, con /clear al passo 4
  regola-<n>   1 leggi src/a.php; 2 /compact; 3 elenca; 4 leggi; 5 elenca
Di ognuna tre file: <nome>.jsonl, lo stream; <nome>.caricamenti.jsonl, il
registro dell'hook InstructionsLoaded della copia, una copia di
tools/registra_caricamenti.py; <nome>.sessione.json, le parole della copia e
i passi, con quante righe aveva il registro alla fine di ognuno: così ogni
caricamento appartiene a un passo. Un risultato dello stream per ogni
messaggio e comando, nell'ordine.

Le garanzie del prodotto, a ogni esecuzione:
  modifica        compact e clear: dopo la modifica (passo 3) la risposta ha
                  ancora la parola caricata all'avvio, non quella nuova;
  compact_disco   compact e regola: dopo /compact il registro ha un
                  caricamento compact di CLAUDE.md;
  compact_nuovo   compact: dopo /compact (passo 5) la risposta ha la parola
                  nuova;
  clear_nuovo     clear: dopo /clear (passo 5) la risposta ha la parola nuova
                  e non quella di prima;
  regola_lettura  regola: dopo il Read di src/a.php (passo 1) un
                  path_glob_match di .claude/rules/php.md, trigger src/a.php.
Il verdetto è «confermata», «non confermata in questa esecuzione» o «non
distinguibile (perché)»: la sessione non ha messo alla prova la garanzia
(la prima risposta non ha la parola, /compact non ha compattato, Claude non
ha letto il file). Tutti e due gli ultimi escono con 1. Il controllo legge gli
stream e i registri, mai un file di esiti.

La regola con paths dopo /compact (passi 2-5 della sessione regola) non è una
garanzia del controllo. La pagina dice che Claude Code la ricarica quando
serve e che la compaction la riassume; la prova del corso del 7 novembre
2026, con Claude Code 2.1.319, in una sessione sola, non ha visto nessun suo
caricamento dopo /compact al Read di un file che corrisponde. Dopo le
garanzie il controllo stampa perciò un reperto, mai un esito né un'uscita:
la data e la versione delle esecuzioni che legge (da sessione.json e dallo
stream); in quante sessioni regola, con il Read di src/a.php riuscito al
passo 4, il registro non ha nessun caricamento della regola dopo /compact;
in quante la parola della regola è nella risposta subito dopo /compact, al
passo 3.

Come dati, mai come esito né come uscita: per ogni passo la risposta, le
parole che vi compaiono, i Read, i caricamenti, i turni e i secondi; i token
prima e dopo la compaction, e quali parole porta il riassunto; per la regola,
se la sua parola c'è nella risposta dopo /compact, prima e dopo aver riletto
src/a.php (la documentazione dice «summarizes them away»), e i suoi
caricamenti dopo /compact; i caricamenti dopo /clear; per ogni sessione
turni, secondi e token, sommati su ogni risultato: i token da
model_usage_since_last_result, tutti i modelli, la compaction compresa, e
accanto quelli di usage.

Uso:    python3 controlla_sessione.py [<spazio di lavoro>]
Env:    PN_HANDSON_ROOT  il repository, per tools/lib_leggi_contesto.py
                         (default: dal percorso di questo file)
Uscita: 0 almeno un'esecuzione completa, ogni file si legge, ogni garanzia
          confermata
        1 manca risposte/; nessuna esecuzione; un file che manca, vuoto o che
          non è ciò che deve essere; una garanzia non confermata o non
          distinguibile
        2 uso sbagliato; lo spazio di lavoro assente; tools/ che non si trova;
          un file che non si legge; un errore inatteso (una riga, mai un
          traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

CARTELLA = "risposte"
TIPI = ("compact", "clear", "regola")
RE_NOME = re.compile(r"^(?:compact|clear|regola)-([1-9][0-9]*)\.jsonl$")
RE_PAROLA = re.compile(r"^[A-Z]+-[A-Z]{6}$")
PAROLE = {"compact": (("radice", "PRIMA"), ("nuova", "DOPO"),
                      ("regolaphp", "REGOLAPHP")),
          "clear": (("radice", "PRIMA"), ("nuova", "DOPO"),
                    ("regolaphp", "REGOLAPHP")),
          "regola": (("radice", "RADICE"), ("regolaphp", "REGOLAPHP"))}
PASSI = {"compact": ("messaggio", "modifica", "messaggio", "/compact",
                     "messaggio"),
         "clear": ("messaggio", "modifica", "messaggio", "/clear",
                   "messaggio"),
         "regola": ("messaggio", "/compact", "messaggio", "messaggio",
                    "messaggio")}
RADICE = "CLAUDE.md"
REGOLA_PHP = ".claude/rules/php.md"
LETTURA_PHP = "src/a.php"
INIZIO_RIASSUNTO = "This session is being continued"
CHIAVI_TOKEN = ("inputTokens", "outputTokens", "cacheReadInputTokens",
                "cacheCreationInputTokens")
CHIAVI_USAGE = ("input_tokens", "output_tokens", "cache_read_input_tokens",
                "cache_creation_input_tokens")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
ETICHETTE = (
    ("modifica", "Una modifica a CLAUDE.md a sessione avviata non si "
                 "applica"),
    ("compact_disco", "Dopo /compact il CLAUDE.md della radice si rilegge "
                      "dal disco"),
    ("compact_nuovo", "Il contenuto nuovo si carica al /compact successivo"),
    ("clear_nuovo", "Il contenuto nuovo si carica al /clear successivo"),
    ("regola_lettura", "La regola con paths si carica quando Claude legge "
                       "un file che corrisponde"))
PER_TIPO = {"compact": ("modifica", "compact_disco", "compact_nuovo"),
            "clear": ("modifica", "clear_nuovo"),
            "regola": ("regola_lettura", "compact_disco")}
PAGINA_REGOLE = "https://code.claude.com/docs/en/context-window"
DICE_RICARICA = ("Rules with paths: frontmatter | Claude Code reloads them "
                 "on demand")
DICE_RIASSUME = ("Path-scoped rules and nested CLAUDE.md files load into "
                 "message history when Claude reads, writes, or edits their "
                 "trigger file, so compaction summarizes them away")
MESI = ("gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre")
RE_INIZIO = re.compile(r"^([0-9]{4})-([0-9]{2})-([0-9]{2})T")
TUTTE = "Ogni garanzia è confermata in ogni esecuzione."
SEGNALARE = ("Una garanzia non confermata è un esito da segnalare: la riga "
             "qui sopra dice in quale sessione.")
NON_ANCORA = ("Non ancora: una sessione non ha messo alla prova una "
              "garanzia: per rifarla, tools/reset_esercizio.sh M6-D04 e di "
              "nuovo in_classe.sh.")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NESSUNA = ("Non ancora: nessuna esecuzione in risposte/: eseguite i passi del "
           "README.")
RIFARE = ("Non ancora: una sessione manca o non va (qui sopra): per rifarla, "
          "tools/reset_esercizio.sh M6-D04 e di nuovo in_classe.sh.")
RIFAI = "rifate la demo"
USO = "Uso: python3 controlla_sessione.py [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che non si legge, tools/ che non si trova: uscita 2."""


class Mancante(Exception):
    """Un file che manca o non va: uscita 1."""


class Lettura(NamedTuple):
    percorso: str
    riuscito: bool


class Passo(NamedTuple):
    """Un passo della sessione, con ciò che dicono lo stream e il registro."""
    numero: int
    tipo: str
    testo: str
    risposta: str
    turni: int
    millisecondi: int
    locale: Optional[str]
    compattato: Optional[Tuple[int, int]]
    azzerato: bool
    letture: List[Lettura]
    caricamenti: list
    token: int
    token_usage: int
    riassunto: str


class Sessione(NamedTuple):
    """Una sessione: i suoi passi, il giorno del primo passo («7 novembre
    2026», vuoto se sessione.json non lo dice) e la versione di Claude Code
    dello stream (vuota se non la dice)."""
    nome: str
    tipo: str
    parole: Dict[str, str]
    passi: List[Passo]
    giorno: str
    versione: str


def migliaia(numero: int) -> str:
    return "{:,}".format(numero).replace(",", ".")


def in_secondi(millisecondi: int) -> str:
    return ("%.1f" % (millisecondi / 1000)).replace(".", ",")


def si_no(vero: bool) -> str:
    return "sì" if vero else "no"


def quanti_turni(turni: int) -> str:
    return "%d %s" % (turni, "turno" if turni == 1 else "turni")


def carica_strumenti() -> object:
    """tools/lib_leggi_contesto.py del repository. Precondizione se manca."""
    radice = os.path.abspath(os.environ.get("PN_HANDSON_ROOT") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), *[os.pardir] * 5))
    strumenti = os.path.join(radice, "tools")
    if not os.path.isfile(os.path.join(strumenti, "lib_leggi_contesto.py")):
        raise Precondizione("non trovo tools/lib_leggi_contesto.py in %s: "
                            "date PN_HANDSON_ROOT, la cartella delle "
                            "esercitazioni" % radice)
    sys.path.insert(0, strumenti)
    # pylint: disable=import-outside-toplevel
    import lib_leggi_contesto
    return lib_leggi_contesto


def leggi_testo(rel: str) -> str:
    if not os.path.lexists(rel):
        raise Mancante("manca %s: %s" % (rel, RIFAI))
    try:
        with open(rel, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (rel, exc.strerror or exc))


def numero(valore: object) -> int:
    if isinstance(valore, bool) or not isinstance(valore, (int, float)):
        return 0
    return int(valore)


def leggi_eventi(rel: str) -> List[dict]:
    """Gli eventi di uno stream; Mancante se è vuoto o rovinato."""
    testo = leggi_testo(rel)
    if not testo.strip():
        raise Mancante("%s è vuoto: la sessione è fallita? %s" % (rel, RIFAI))
    eventi = []
    for riga_n, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            raise Mancante("%s, riga %d: non è JSON; %s" % (rel, riga_n, RIFAI))
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un oggetto JSON; %s"
                           % (rel, riga_n, RIFAI))
        eventi.append(evento)
    return eventi


def segmenti(eventi: List[dict], rel: str) -> List[List[dict]]:
    """Gli eventi divisi per risultato: il segmento k finisce con il k-esimo
    evento result. Mancante se un risultato è un errore o non dice
    num_turns."""
    fatti: List[List[dict]] = []
    corrente: List[dict] = []
    for evento in eventi:
        corrente.append(evento)
        if evento.get("type") != "result":
            continue
        if evento.get("is_error") \
                or evento.get("subtype", "success") != "success":
            raise Mancante("%s: claude ha restituito un errore; %s"
                           % (rel, RIFAI))
        valore = evento.get("num_turns")
        if isinstance(valore, bool) or not isinstance(valore, (int, float)):
            raise Mancante("%s: un risultato non dice num_turns; %s"
                           % (rel, RIFAI))
        fatti.append(corrente)
        corrente = []
    return fatti


def token_di(uso: object, chiavi: Tuple[str, ...]) -> int:
    return sum(numero(uso.get(c)) for c in chiavi) \
        if isinstance(uso, dict) else 0


def token_del_risultato(risultato: dict) -> Tuple[int, int]:
    """(i token di tutti i modelli dall'ultimo risultato, quelli di usage).
    Senza model_usage_since_last_result, quelli di usage."""
    usage = token_di(risultato.get("usage"), CHIAVI_USAGE)
    modelli = risultato.get("model_usage_since_last_result")
    if not isinstance(modelli, dict):
        return usage, usage
    return sum(token_di(d, CHIAVI_TOKEN) for d in modelli.values()), usage


def risultati_dei_tool(eventi: List[dict]) -> Dict[str, bool]:
    """Per ogni tool_use_id, se il suo tool_result è riuscito."""
    esiti: Dict[str, bool] = {}
    for evento in eventi:
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") \
            if isinstance(messaggio, dict) else None
        if evento.get("type") != "user" or not isinstance(contenuto, list):
            continue
        for blocco in contenuto:
            if isinstance(blocco, dict) \
                    and blocco.get("type") == "tool_result" \
                    and isinstance(blocco.get("tool_use_id"), str):
                esiti[blocco["tool_use_id"]] = not blocco.get("is_error")
    return esiti


def letture_di(segmento: List[dict], esiti: Dict[str, bool]) -> List[Lettura]:
    letture: List[Lettura] = []
    visti = set()
    for evento in segmento:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" \
                or evento.get("parent_tool_use_id") \
                or not isinstance(messaggio, dict) \
                or not isinstance(messaggio.get("content"), list):
            continue
        for blocco in messaggio["content"]:
            if not isinstance(blocco, dict) or blocco.get("type") \
                    != "tool_use" or blocco.get("name") != "Read":
                continue
            ident = blocco.get("id")
            if ident in visti:
                continue
            visti.add(ident)
            ingresso = blocco.get("input")
            percorso = ingresso.get("file_path") \
                if isinstance(ingresso, dict) else None
            if isinstance(percorso, str) and percorso:
                letture.append(Lettura(percorso, esiti.get(ident, False)))
    return letture


def riassunto_di(segmento: List[dict]) -> str:
    """Il riassunto della compaction: il messaggio utente che lo porta."""
    for evento in segmento:
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") \
            if isinstance(messaggio, dict) else None
        if evento.get("type") == "user" and isinstance(contenuto, str) \
                and contenuto.startswith(INIZIO_RIASSUNTO):
            return contenuto
    return ""


def compattato(segmento: List[dict]) -> Optional[Tuple[int, int]]:
    """I token prima e dopo, se il segmento ha un compact_boundary."""
    for evento in segmento:
        if evento.get("type") == "system" \
                and evento.get("subtype") == "compact_boundary":
            dati = evento.get("compact_metadata")
            dati = dati if isinstance(dati, dict) else {}
            return numero(dati.get("pre_tokens")), numero(
                dati.get("post_tokens"))
    return None


def corrisponde(percorso: str, rel: str) -> bool:
    percorso = os.path.normpath(percorso).replace(os.sep, "/")
    return percorso == rel or percorso.endswith("/" + rel)


def leggi_dati(rel: str, tipo: str) -> Tuple[Dict[str, str], List[dict]]:
    """Le parole e i passi di sessione.json. Mancante se non vanno."""
    try:
        dato = json.loads(leggi_testo(rel))
    except ValueError:
        raise Mancante("%s non è JSON; %s" % (rel, RIFAI))
    parole = dato.get("parole") if isinstance(dato, dict) else None
    passi = dato.get("passi") if isinstance(dato, dict) else None
    if not isinstance(parole, dict) or not isinstance(passi, list) \
            or dato.get("tipo") != tipo:
        raise Mancante("%s non dice il tipo %s, le parole e i passi; %s"
                       % (rel, tipo, RIFAI))
    for chiave, prefisso in PAROLE[tipo]:
        parola = parole.get(chiave)
        if not isinstance(parola, str) or not RE_PAROLA.match(parola) \
                or not parola.startswith(prefisso + "-"):
            raise Mancante("%s: la parola «%s» manca o non è nella forma "
                           "%s-XXXXXX; %s" % (rel, chiave, prefisso, RIFAI))
    attesi = PASSI[tipo]
    fatti = [p.get("testo") if isinstance(p, dict) and p.get("tipo")
             == "comando" else (p.get("tipo") if isinstance(p, dict) else None)
             for p in passi]
    if tuple(fatti) != attesi or not all(
            isinstance(p.get("caricamenti"), int) for p in passi):
        raise Mancante("%s non ha i passi di una sessione %s (la sessione si "
                       "è fermata a metà?); %s" % (rel, tipo, RIFAI))
    return parole, passi


def finestre(caricamenti: list, passi: List[dict], rel: str) -> List[list]:
    """I caricamenti di ogni passo; quelli dopo l'ultimo segno vanno
    all'ultimo passo."""
    segni = [p["caricamenti"] for p in passi]
    if any(b < a for a, b in zip([0] + segni, segni)) \
            or segni[-1] > len(caricamenti):
        raise Mancante("%s: i segni del registro non tornano con le sue "
                       "righe; %s" % (rel, RIFAI))
    gruppi = []
    inizio = 0
    for segno in segni:
        gruppi.append(caricamenti[inizio:segno])
        inizio = segno
    gruppi[-1] = gruppi[-1] + caricamenti[inizio:]
    return gruppi


def giorno_di(passi: List[dict]) -> str:
    """Il giorno del primo passo, «7 novembre 2026»; vuoto se non si legge."""
    inizio = passi[0].get("inizio") if passi else None
    fatto = RE_INIZIO.match(inizio) if isinstance(inizio, str) else None
    if not fatto:
        return ""
    anno, mese, giorno = (int(x) for x in fatto.groups())
    if not 1 <= mese <= 12 or not 1 <= giorno <= 31:
        return ""
    return "%d %s %d" % (giorno, MESI[mese - 1], anno)


def versione_di(eventi: List[dict]) -> str:
    """La versione di Claude Code del primo system/init che la dice."""
    for evento in eventi:
        if evento.get("type") == "system" and evento.get("subtype") == "init":
            versione = evento.get("claude_code_version")
            if isinstance(versione, str) and versione.strip():
                return versione.strip()
    return ""


def leggi_sessione(nome: str, tipo: str, lc: object) -> Sessione:
    base = "%s/%s" % (CARTELLA, nome)
    eventi = leggi_eventi(base + ".jsonl")
    leggi_testo(base + ".caricamenti.jsonl")
    try:
        caricamenti = lc.leggi_caricamenti(base + ".caricamenti.jsonl")
    except lc.Problema as exc:
        raise Mancante("%s; %s" % (exc, RIFAI))
    parole, dati = leggi_dati(base + ".sessione.json", tipo)
    pezzi = segmenti(eventi, base + ".jsonl")
    inviati = [p for p in dati if p["tipo"] != "modifica"]
    if len(pezzi) != len(inviati):
        raise Mancante("%s.jsonl: %d risultati per %d messaggi; %s"
                       % (base, len(pezzi), len(inviati), RIFAI))
    gruppi = finestre(caricamenti, dati, base + ".caricamenti.jsonl")
    esiti = risultati_dei_tool(eventi)
    passi: List[Passo] = []
    coda = iter(pezzi)
    for dato, gruppo in zip(dati, gruppi):
        if dato["tipo"] == "modifica":
            passi.append(Passo(dato.get("passo", len(passi) + 1), "modifica",
                               str(dato.get("testo", "")), "", 0, 0, None,
                               None, False, [], gruppo, 0, 0, ""))
            continue
        segmento = next(coda)
        risultato = segmento[-1]
        risposta = risultato.get("result")
        tutti, usage = token_del_risultato(risultato)
        locale = risultato.get("local_command")
        passi.append(Passo(
            numero=dato.get("passo", len(passi) + 1), tipo=dato["tipo"],
            testo=str(dato.get("testo", "")),
            risposta=risposta if isinstance(risposta, str) else "",
            turni=numero(risultato.get("num_turns")),
            millisecondi=numero(risultato.get("duration_ms")),
            locale=locale if isinstance(locale, str) else None,
            compattato=compattato(segmento),
            azzerato=any(e.get("type") == "conversation_reset"
                         for e in segmento),
            letture=letture_di(segmento, esiti), caricamenti=gruppo,
            token=tutti, token_usage=usage, riassunto=riassunto_di(segmento)))
    return Sessione(nome, tipo, parole, passi, giorno_di(dati),
                    versione_di(eventi))


def trovata(parola: str, testo: str) -> bool:
    return parola.lower() in testo.lower()


def caricati_da(sessione: Sessione, dal_passo: int) -> list:
    """I caricamenti dei passi dal numero dato in poi."""
    return [c for p in sessione.passi[dal_passo - 1:] for c in p.caricamenti]


def letto_bene(passo: Passo, rel: str) -> Optional[bool]:
    """None se il passo non ha letto rel; altrimenti se un Read è riuscito."""
    tentati = [x for x in passo.letture if corrisponde(x.percorso, rel)]
    if not tentati:
        return None
    return any(x.riuscito for x in tentati)


def g_modifica(s: Sessione) -> Tuple[str, str]:
    prima, nuova = s.parole["radice"], s.parole["nuova"]
    primo, dopo = s.passi[0].risposta, s.passi[2].risposta
    if trovata(nuova, dopo):
        return NON_CONFERMATA, ("dopo la modifica la risposta ha la parola "
                                "nuova, %s" % nuova)
    if not trovata(prima, primo):
        return NON_DISTINGUIBILE, ("al primo messaggio la risposta non ha la "
                                   "parola di CLAUDE.md")
    if not trovata(prima, dopo):
        return NON_DISTINGUIBILE, ("dopo la modifica la risposta non ha "
                                   "nessuna delle due parole")
    return CONFERMATA, ("prima e dopo la modifica la parola caricata "
                        "all'avvio, %s" % prima)


def g_compact_disco(s: Sessione) -> Tuple[str, str]:
    numero_c = 4 if s.tipo == "compact" else 2
    if s.passi[numero_c - 1].compattato is None:
        return NON_DISTINGUIBILE, ("/compact non ha compattato: nessun "
                                   "compact_boundary")
    if any(c.load_reason == "compact" and c.file_path == RADICE
           for c in caricati_da(s, numero_c)):
        return CONFERMATA, "dopo /compact il registro ha compact per CLAUDE.md"
    return NON_CONFERMATA, ("dopo /compact nessun caricamento compact di "
                            "CLAUDE.md")


def g_compact_nuovo(s: Sessione) -> Tuple[str, str]:
    prima, nuova = s.parole["radice"], s.parole["nuova"]
    if s.passi[3].compattato is None:
        return NON_DISTINGUIBILE, ("/compact non ha compattato: nessun "
                                   "compact_boundary")
    ultima = s.passi[4].risposta
    if trovata(nuova, ultima):
        return CONFERMATA, "dopo /compact la parola nuova, %s%s" % (
            nuova, " (c'è anche quella di prima)" if trovata(prima, ultima)
            else "")
    if trovata(prima, ultima):
        return NON_CONFERMATA, ("dopo /compact la risposta ha ancora la "
                                "parola di prima")
    return NON_DISTINGUIBILE, ("dopo /compact la risposta non ha nessuna "
                               "delle due parole")


def g_clear_nuovo(s: Sessione) -> Tuple[str, str]:
    prima, nuova = s.parole["radice"], s.parole["nuova"]
    if not s.passi[3].azzerato:
        return NON_DISTINGUIBILE, ("/clear non ha aperto una conversazione "
                                   "nuova: nessun conversation_reset")
    ultima = s.passi[4].risposta
    if trovata(prima, ultima):
        return NON_CONFERMATA, ("dopo /clear la risposta ha la parola di "
                                "prima, %s" % prima)
    if trovata(nuova, ultima):
        return CONFERMATA, "dopo /clear la parola nuova, %s" % nuova
    return NON_DISTINGUIBILE, ("dopo /clear la risposta non ha nessuna delle "
                               "due parole")


def g_regola_lettura(s: Sessione) -> Tuple[str, str]:
    letto = letto_bene(s.passi[0], LETTURA_PHP)
    if letto is None:
        return NON_DISTINGUIBILE, "Claude non ha letto %s" % LETTURA_PHP
    if not letto:
        return NON_DISTINGUIBILE, "il Read di %s non è riuscito" % LETTURA_PHP
    if any(c.load_reason == "path_glob_match" and c.file_path == REGOLA_PHP
           and c.trigger_file_path == LETTURA_PHP
           for c in s.passi[0].caricamenti):
        return CONFERMATA, ("Read di %s, poi path_glob_match di %s con "
                            "trigger %s" % (LETTURA_PHP, REGOLA_PHP,
                                            LETTURA_PHP))
    return NON_CONFERMATA, ("dopo il Read di %s nessun path_glob_match di %s"
                            % (LETTURA_PHP, REGOLA_PHP))


GIUDICI = {"modifica": g_modifica, "compact_disco": g_compact_disco,
           "compact_nuovo": g_compact_nuovo, "clear_nuovo": g_clear_nuovo,
           "regola_lettura": g_regola_lettura}


def regola_dopo_compact(s: Sessione) -> list:
    """I caricamenti di .claude/rules/php.md dal passo di /compact in poi."""
    return [c for c in caricati_da(s, 2) if c.file_path == REGOLA_PHP]


def tutti_diversi(valori: List[str]) -> List[str]:
    """I valori non vuoti, ciascuno una volta, nell'ordine."""
    visti: List[str] = []
    for valore in valori:
        if valore and valore not in visti:
            visti.append(valore)
    return visti


def reperto(regole: List[Sessione]) -> str:
    """Il reperto sulla regola con paths dopo /compact: un dato, mai un esito
    né un'uscita. Conta le sessioni regola che hanno compattato; di quelle in
    cui il Read di src/a.php del passo 4 è riuscito, quante non hanno nessun
    caricamento della regola dopo /compact; e in quante la parola della
    regola è nella risposta del passo 3, subito dopo /compact."""
    compattate = [s for s in regole if s.passi[1].compattato is not None]
    rilette = [s for s in compattate if letto_bene(s.passi[3], LETTURA_PHP)]
    senza = [s for s in rilette if not regola_dopo_compact(s)]
    con_parola = [s for s in compattate
                  if trovata(s.parole["regolaphp"], s.passi[2].risposta)]
    giorni = tutti_diversi([s.giorno for s in regole])
    versioni = tutti_diversi([s.versione for s in regole])
    quando = "del %s" % " e ".join(giorni) if giorni \
        else "di un giorno che sessione.json non dice"
    con = "con Claude Code %s" % " e ".join(versioni) if versioni \
        else "con una versione di Claude Code che lo stream non dice"
    return ("Reperto: la pagina dice «%s» e «%s» (%s); in queste esecuzioni, "
            "%s, %s, in una sessione sola: nessun caricamento della regola "
            "dopo /compact al Read di un file che corrisponde, %d su %d, e la "
            "parola della regola nella risposta subito dopo /compact, %d su "
            "%d." % (DICE_RICARICA, DICE_RIASSUME, PAGINA_REGOLE, quando, con,
                     len(senza), len(rilette), len(con_parola),
                     len(compattate)))


def riga_caricamento(car: object) -> str:
    dettagli = []
    if car.trigger_file_path:
        dettagli.append("trigger %s" % car.trigger_file_path)
    if car.parent_file_path:
        dettagli.append("da %s" % car.parent_file_path)
    riga = "%s %s" % (car.load_reason, car.file_path)
    return riga + (" (%s)" % "; ".join(dettagli) if dettagli else "")


def breve(testo: str) -> str:
    testo = " ".join(testo.split())
    return testo[:79] + "…" if len(testo) > 80 else testo


def mostrata(tipo: str, chiave: str) -> str:
    """Il nome di una parola nelle righe dei dati: prima e nuova nelle
    sessioni con la modifica, radice e regola in quella della regola."""
    if chiave == "radice":
        return "radice" if tipo == "regola" else "prima"
    return "regola" if chiave == "regolaphp" else chiave


def parole_in(s: Sessione, testo: str) -> str:
    """«prima sì; nuova no» o «radice sì; regola no»: le parole della
    sessione in un testo."""
    return "; ".join("%s %s" % (mostrata(s.tipo, chiave), si_no(trovata(
        s.parole[chiave], testo))) for chiave, _ in PAROLE[s.tipo]
        if chiave != "regolaphp" or s.tipo == "regola")


def stampa_passo(s: Sessione, passo: Passo) -> None:
    caricamenti = "; ".join(riga_caricamento(c) for c in passo.caricamenti) \
        or "nessuno"
    if passo.tipo == "modifica":
        print("  %d. CLAUDE.md riscritto da fuori, con %s; caricamenti: %s"
              % (passo.numero, s.parole["nuova"], caricamenti))
        return
    if passo.tipo == "comando":
        if passo.compattato:
            esito = "compattato, %s → %s token; nel riassunto: %s" % (
                migliaia(passo.compattato[0]), migliaia(passo.compattato[1]),
                parole_in(s, passo.riassunto) if passo.riassunto
                else "nessun riassunto nello stream")
        else:
            esito = "conversazione nuova" if passo.azzerato \
                else "nessun effetto nello stream"
        print("  %d. %s → %s; caricamenti: %s; %s; %s s" % (
            passo.numero, passo.testo, esito, caricamenti,
            quanti_turni(passo.turni), in_secondi(passo.millisecondi)))
        return
    parole = parole_in(s, passo.risposta)
    letture = ", ".join(os.path.basename(os.path.dirname(x.percorso)) + "/"
                        + os.path.basename(x.percorso) for x in passo.letture)
    print("  %d. «%s» → «%s»; parole: %s; Read: %s; caricamenti: %s; %s; "
          "%s s" % (passo.numero, breve(passo.testo), breve(passo.risposta),
                    parole, letture or "nessuno", caricamenti,
                    quanti_turni(passo.turni), in_secondi(passo.millisecondi)))


def stampa_sessione(s: Sessione, n: int) -> None:
    print("%s, %d:" % (s.tipo, n))
    for passo in s.passi:
        stampa_passo(s, passo)
    print("  consumo: %s; token %s (usage %s); %s s" % (
        quanti_turni(sum(p.turni for p in s.passi)),
        migliaia(sum(p.token for p in s.passi)),
        migliaia(sum(p.token_usage for p in s.passi)),
        in_secondi(sum(p.millisecondi for p in s.passi))))
    if s.tipo == "regola":
        regola = s.parole["regolaphp"]
        print("  Come dato, la parola della regola nella risposta dopo "
              "/compact, prima di rileggere src/a.php: %s; dopo averlo "
              "riletto: %s." % (si_no(trovata(regola, s.passi[2].risposta)),
                                si_no(trovata(regola, s.passi[4].risposta))))
        print("  Come dato, i caricamenti della regola dopo /compact: %s."
              % ("; ".join(riga_caricamento(c)
                           for c in regola_dopo_compact(s)) or "nessuno"))


def numeri_delle_esecuzioni() -> List[int]:
    numeri = set()
    for nome in os.listdir(CARTELLA):
        fatto = RE_NOME.match(nome)
        if fatto:
            numeri.add(int(fatto.group(1)))
    return sorted(numeri)


def avviso(messaggio: str) -> None:
    sys.stderr.write("controlla_sessione.py: %s\n" % messaggio)


def leggi_tutto(numeri: List[int], lc: object
                ) -> Optional[Dict[str, Sessione]]:
    sessioni: Dict[str, Sessione] = {}
    mancanti = 0
    for n in numeri:
        for tipo in TIPI:
            nome = "%s-%d" % (tipo, n)
            try:
                sessioni[nome] = leggi_sessione(nome, tipo, lc)
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
    return None if mancanti else sessioni


def riepilogo(etichetta: str, esiti: List[str]) -> str:
    confermate = esiti.count(CONFERMATA)
    riga = "%s: %s %d su %d" % (etichetta, CONFERMATA, confermate, len(esiti))
    for altro in (NON_CONFERMATA, NON_DISTINGUIBILE):
        if altro in esiti:
            riga += "; %s %d" % (altro, esiti.count(altro))
    return riga


def controlla(lc: object) -> int:
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    numeri = numeri_delle_esecuzioni()
    if not numeri:
        print(NESSUNA)
        return 1
    sessioni = leggi_tutto(numeri, lc)
    if sessioni is None:
        print(RIFARE)
        return 1
    esiti: Dict[str, List[str]] = {chiave: [] for chiave, _ in ETICHETTE}
    nomi = dict(ETICHETTE)
    for n in numeri:
        for tipo in TIPI:
            s = sessioni["%s-%d" % (tipo, n)]
            stampa_sessione(s, n)
            for chiave in PER_TIPO[tipo]:
                esito, perche = GIUDICI[chiave](s)
                esiti[chiave].append(esito)
                print("%s (%s, %d): %s (%s)" % (nomi[chiave], tipo, n, esito,
                                                perche))
        print()
    for chiave, etichetta in ETICHETTE:
        print(riepilogo(etichetta, esiti[chiave]))
    print("\n" + reperto([sessioni["regola-%d" % n] for n in numeri]))
    print("\nCome dato, tutte le %d sessioni: turni %d; token %s (usage %s); "
          "%s s." % (len(sessioni),
                     sum(p.turni for s in sessioni.values() for p in s.passi),
                     migliaia(sum(p.token for s in sessioni.values()
                                  for p in s.passi)),
                     migliaia(sum(p.token_usage for s in sessioni.values()
                                  for p in s.passi)),
                     in_secondi(sum(p.millisecondi for s in sessioni.values()
                                    for p in s.passi))))
    tutti = [v for lista in esiti.values() for v in lista]
    if NON_CONFERMATA in tutti:
        print(SEGNALARE)
        return 1
    if NON_DISTINGUIBILE in tutti:
        print(NON_ANCORA)
        return 1
    print(TUTTE)
    return 0


def errore(messaggio: str) -> int:
    avviso(messaggio)
    return 2


def esegui(argv: List[str]) -> int:
    sconosciute = [a for a in argv if a.startswith("-")]
    if sconosciute:
        errore("opzione sconosciuta: %s" % sconosciute[0])
        sys.stderr.write(USO)
        return 2
    if len(argv) > 1:
        errore("uno spazio di lavoro per volta")
        sys.stderr.write(USO)
        return 2
    ws = argv[0] if argv else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    lc = carica_strumenti()
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    return controlla(lc)


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
