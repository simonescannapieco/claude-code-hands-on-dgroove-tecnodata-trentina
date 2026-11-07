"""controlla_caricamento.py -- le garanzie della demo M6-D02 «Che cosa entra
all'avvio, e che cosa quando serve» alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente), ciò che
in_classe.sh lascia in risposte/:
  avvio-<n>        .jsonl, .caricamenti.jsonl e .parole.json: claude -p senza
                   strumenti (--tools ""), che elenca le parole in codice delle
                   sue istruzioni di progetto;
  lettura-<n>      gli stessi tre file: solo Read, legge src/a.php e
                   sub/nota.txt, poi elenca le parole;
  costo-<braccio>  .jsonl e .caricamenti.jsonl dei bracci base, commento,
                   inline e import, «Rispondi solo: ok».
Il registro (.caricamenti.jsonl) è quello che l'hook InstructionsLoaded della
copia, una copia di tools/registra_caricamenti.py, ha scritto durante la
chiamata; le parole (.parole.json) sono le nove della copia, una per posto.

Le garanzie del prodotto, a ogni esecuzione:
  avvio         session_start per CLAUDE.md, CLAUDE.local.md e
                .claude/rules/generale.md (avvio e lettura);
  import        include di docs/glossario.md, con parent_file_path CLAUDE.md
                (avvio e lettura);
  backtick      docs/escluso.md mai nel registro (avvio e lettura); in avvio
                la sua parola non è nella risposta;
  commento      in avvio, che non legge file, la parola del commento non è
                nella risposta;
  su_richiesta  in avvio né .claude/rules/php.md né sub/CLAUDE.md nel
                registro, né le loro parole nella risposta;
  regola        in lettura, dopo il Read di src/a.php, path_glob_match di
                .claude/rules/php.md con trigger_file_path src/a.php;
  annidato      in lettura, dopo il Read di sub/nota.txt, nested_traversal di
                sub/CLAUDE.md con trigger_file_path sub/nota.txt.
Il verdetto è «confermata», «non confermata in questa esecuzione» o «non
distinguibile (perché)». Una garanzia che si legge nella risposta (commento,
backtick e su_richiesta in avvio) è non distinguibile se la risposta non ha
la parola della radice: Claude non ha detto che cosa vede. Una che segue un
Read è non distinguibile se quel Read non c'è o non è riuscito. Non dicono
niente sulla garanzia, ma non l'hanno messa alla prova: anche loro escono con
1, e l'esecuzione si rifà. Il controllo legge gli stream e i registri, mai un
file di esiti.

Come dati, mai come esito né come uscita: la risposta; le parole che vi
compaiono, posto per posto; gli strumenti chiamati; i caricamenti; la prima
richiesta; turni, token e secondi sommati su ogni risultato; i quattro bracci
di costo: la prima richiesta di ognuno, il commento sul braccio base, lo
stesso testo visibile, l'import contro il testo incollato (import ≥ inline:
sì o no).

Uso:    python3 controlla_caricamento.py [<spazio di lavoro>]
Env:    PN_HANDSON_ROOT  il repository, per tools/lib_leggi_contesto.py
                         (default: dal percorso di questo file)
Uscita: 0 almeno un'esecuzione completa, i quattro bracci di costo, ogni
          stream si legge, ogni garanzia confermata
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
CHIAVI = ("radice", "commento", "importato", "citato", "locale", "regola",
          "regolaphp", "annidato", "letto")
POSTI = {"radice": "radice", "commento": "commento",
         "importato": "importato", "citato": "fra backtick",
         "locale": "locale", "regola": "regola", "regolaphp": "regola PHP",
         "annidato": "sub/CLAUDE.md", "letto": "file letto"}
RE_PAROLA = re.compile(r"^[A-Z]+-[A-Z]{6}$")
RE_NOME = re.compile(r"^(?:avvio|lettura)-([1-9][0-9]*)\.jsonl$")
BRACCI = ("base", "commento", "inline", "import")
ALL_AVVIO = ("CLAUDE.md", "CLAUDE.local.md", ".claude/rules/generale.md")
IMPORTATO = "docs/glossario.md"
CITATO = "docs/escluso.md"
REGOLA_PHP = ".claude/rules/php.md"
ANNIDATO = "sub/CLAUDE.md"
LETTURA_PHP = "src/a.php"
LETTURA_SUB = "sub/nota.txt"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
ETICHETTE = (
    ("avvio", "All'avvio si caricano CLAUDE.md, CLAUDE.local.md e la regola "
              "senza paths"),
    ("import", "Il file importato con @ si carica con CLAUDE.md"),
    ("backtick", "Un percorso fra backtick non si importa"),
    ("commento", "Il commento HTML a blocco non entra nel contesto"),
    ("su_richiesta", "La regola con paths e il CLAUDE.md di sub/ non si "
                     "caricano all'avvio"),
    ("regola", "La regola con paths si carica quando Claude legge un file "
               "che corrisponde"),
    ("annidato", "Il CLAUDE.md di sub/ si carica quando Claude legge un file "
                 "di sub/"))
PER_TIPO = {"avvio": ("avvio", "import", "backtick", "commento",
                      "su_richiesta"),
            "lettura": ("avvio", "import", "backtick", "regola", "annidato")}
SENZA_RADICE = ("la risposta non ha la parola della radice: Claude non ha "
                "detto che cosa vede")
TUTTE = "Ogni garanzia è confermata in ogni esecuzione."
SEGNALARE = ("Una garanzia non confermata è un esito da segnalare: la riga "
             "qui sopra dice in quale esecuzione.")
NON_ANCORA = ("Non ancora: un'esecuzione non ha messo alla prova una "
              "garanzia: per rifarla, tools/reset_esercizio.sh M6-D02 e di "
              "nuovo in_classe.sh.")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NESSUNA = ("Non ancora: nessuna esecuzione in risposte/: eseguite i passi del "
           "README.")
RIFARE = ("Non ancora: una risposta manca o non va (qui sopra): per rifarla, "
          "tools/reset_esercizio.sh M6-D02 e di nuovo in_classe.sh.")
RIFAI = "rifate la demo"
USO = "Uso: python3 controlla_caricamento.py [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che non si legge, tools/ che non si trova: uscita 2."""


class Mancante(Exception):
    """Un file che manca o non va: uscita 1."""


class Lettura(NamedTuple):
    """Un Read della conversazione principale: il percorso e se è riuscito."""
    percorso: str
    riuscito: bool


class Corsa(NamedTuple):
    """Una chiamata: che cosa dicono il suo stream e il suo registro."""
    nome: str
    testo: str
    prima_richiesta: int
    turni: int
    token: int
    secondi: float
    strumenti: List[str]
    letture: List[Lettura]
    caricamenti: list
    parole: Dict[str, str]


def migliaia(numero: int) -> str:
    """Il numero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def con_segno(numero: int) -> str:
    """«+707», «-12», «+0»."""
    return ("-" if numero < 0 else "+") + migliaia(abs(numero))


def in_secondi(secondi: float) -> str:
    """I secondi con la virgola."""
    return ("%.1f" % secondi).replace(".", ",")


def si_no(vero: bool) -> str:
    return "sì" if vero else "no"


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


def dice_i_turni(risultato: dict) -> bool:
    valore = risultato.get("num_turns")
    return isinstance(valore, (int, float)) and not isinstance(valore, bool)


def leggi_eventi(rel: str) -> List[dict]:
    """Gli eventi di uno stream-json riuscito di claude -p."""
    testo = leggi_testo(rel)
    if not testo.strip():
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? %s"
                       % (rel, RIFAI))
    eventi = []
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            raise Mancante("%s, riga %d: non è JSON; %s" % (rel, numero, RIFAI))
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
        raise Mancante("%s: un risultato non dice num_turns; %s" % (rel, RIFAI))
    return eventi


def normale(percorso: str) -> str:
    return os.path.normpath(percorso).replace(os.sep, "/")


def corrisponde(percorso: str, rel: str) -> bool:
    """Vero se il percorso, assoluto o relativo, è il file rel della copia."""
    percorso = normale(percorso)
    return percorso == rel or percorso.endswith("/" + rel)


def cartella_di_lavoro(eventi: List[dict]) -> str:
    for evento in eventi:
        if evento.get("type") == "system" and evento.get("subtype") == "init":
            cwd = evento.get("cwd")
            return normale(cwd) if isinstance(cwd, str) and cwd else ""
    return ""


def mostra(percorso: str, cwd: str) -> str:
    """Un percorso letto, relativo alla copia quando si sa dov'era."""
    percorso = normale(percorso)
    if cwd and percorso.startswith(cwd + "/"):
        return percorso[len(cwd) + 1:]
    return "/".join(percorso.split("/")[-2:])


def letture_di(eventi: List[dict], risultati: dict) -> List[Lettura]:
    """I Read della conversazione principale, una volta per id, con l'esito
    del loro tool_result."""
    letture: List[Lettura] = []
    visti = set()
    for evento in eventi:
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
            if not isinstance(percorso, str) or not percorso:
                raise Mancante("un Read senza file_path; %s" % RIFAI)
            esito = risultati.get(ident)
            letture.append(Lettura(percorso, esito is not None
                                   and not esito.errore))
    return letture


def leggi_parole(rel: str) -> Dict[str, str]:
    """Le nove parole di una copia. Mancante se manca o non va."""
    try:
        dato = json.loads(leggi_testo(rel))
    except ValueError:
        raise Mancante("%s non è JSON; %s" % (rel, RIFAI))
    if not isinstance(dato, dict):
        raise Mancante("%s non è un oggetto JSON; %s" % (rel, RIFAI))
    parole = {}
    for chiave in CHIAVI:
        parola = dato.get(chiave)
        if not isinstance(parola, str) or not RE_PAROLA.match(parola) \
                or not parola.startswith(chiave.upper() + "-"):
            raise Mancante("%s: la parola «%s» manca o non è nella forma "
                           "%s-XXXXXX; %s" % (rel, chiave, chiave.upper(),
                                               RIFAI))
        parole[chiave] = parola
    return parole


def leggi_corsa(nome: str, lc: object, con_parole: bool) -> Corsa:
    """Lo stream, il registro e, se ci sono, le parole di una chiamata."""
    base = "%s/%s" % (CARTELLA, nome)
    eventi = leggi_eventi(base + ".jsonl")
    registro = base + ".caricamenti.jsonl"
    leggi_testo(registro)
    try:
        contesto = lc.leggi_contesto(base + ".jsonl")
        caricamenti = lc.leggi_caricamenti(registro)
    except lc.Problema as exc:
        raise Mancante("%s; %s" % (exc, RIFAI))
    esec = contesto.esecuzione
    cwd = cartella_di_lavoro(eventi)
    letture = letture_di(eventi, contesto.risultati)
    strumenti = []
    for strumento in esec.strumenti:
        ingresso = strumento.input if isinstance(strumento.input, dict) \
            else {}
        percorso = ingresso.get("file_path")
        strumenti.append("%s (%s)" % (strumento.nome, mostra(percorso, cwd))
                         if isinstance(percorso, str) else strumento.nome)
    return Corsa(nome=nome, testo=esec.testo,
                 prima_richiesta=contesto.prima_richiesta,
                 turni=int(esec.turni), token=int(esec.token_totali),
                 secondi=float(esec.secondi),
                 strumenti=strumenti, letture=letture, caricamenti=caricamenti,
                 parole=leggi_parole(base + ".parole.json") if con_parole
                 else {})


def trovata(parola: str, testo: str) -> bool:
    """La parola nella risposta, senza guardare le maiuscole."""
    return parola.lower() in testo.lower()


def nella_risposta(corsa: Corsa, chiave: str) -> bool:
    return trovata(corsa.parole[chiave], corsa.testo)


def caricati(corsa: Corsa, motivo: str, percorso: str) -> list:
    return [c for c in corsa.caricamenti
            if c.load_reason == motivo and c.file_path == percorso]


def nel_registro(corsa: Corsa, percorso: str) -> bool:
    return any(c.file_path == percorso for c in corsa.caricamenti)


def riga_caricamento(car: object) -> str:
    """«include docs/glossario.md (da CLAUDE.md)», «path_glob_match … (trigger
    src/a.php; globs **/*.php)»."""
    dettagli = []
    if car.parent_file_path:
        dettagli.append("da %s" % car.parent_file_path)
    if car.trigger_file_path:
        dettagli.append("trigger %s" % car.trigger_file_path)
    if car.globs:
        dettagli.append("globs %s" % ", ".join(car.globs))
    riga = "%s %s" % (car.load_reason, car.file_path)
    return riga + (" (%s)" % "; ".join(dettagli) if dettagli else "")


def giudica_avvio(corsa: Corsa) -> Tuple[str, str]:
    mancano = [f for f in ALL_AVVIO if not caricati(corsa, "session_start", f)]
    if mancano:
        return NON_CONFERMATA, "nessun session_start per %s" % ", ".join(
            mancano)
    return CONFERMATA, ("session_start per CLAUDE.md, CLAUDE.local.md e "
                        ".claude/rules/generale.md")


def giudica_import(corsa: Corsa) -> Tuple[str, str]:
    inclusi = [c for c in caricati(corsa, "include", IMPORTATO)
               if c.parent_file_path == "CLAUDE.md"]
    if inclusi:
        return CONFERMATA, "include di %s, da CLAUDE.md" % IMPORTATO
    if nel_registro(corsa, IMPORTATO):
        return NON_CONFERMATA, ("%s nel registro, ma non come include da "
                                "CLAUDE.md" % IMPORTATO)
    return NON_CONFERMATA, "%s non è nel registro" % IMPORTATO


def giudica_backtick(corsa: Corsa, avvio: bool) -> Tuple[str, str]:
    if nel_registro(corsa, CITATO):
        return NON_CONFERMATA, "%s è nel registro" % CITATO
    if not avvio:
        return CONFERMATA, "%s mai nel registro" % CITATO
    if nella_risposta(corsa, "citato"):
        return NON_CONFERMATA, "la parola di %s è nella risposta" % CITATO
    if not nella_risposta(corsa, "radice"):
        return NON_DISTINGUIBILE, SENZA_RADICE
    return CONFERMATA, ("%s mai nel registro; la sua parola non è nella "
                        "risposta" % CITATO)


def giudica_commento(corsa: Corsa) -> Tuple[str, str]:
    if nella_risposta(corsa, "commento"):
        return NON_CONFERMATA, "la parola del commento è nella risposta"
    if not nella_risposta(corsa, "radice"):
        return NON_DISTINGUIBILE, SENZA_RADICE
    return CONFERMATA, ("la parola del commento non è nella risposta, che ha "
                        "quella della radice")


def giudica_su_richiesta(corsa: Corsa) -> Tuple[str, str]:
    registrati = [f for f in (REGOLA_PHP, ANNIDATO) if nel_registro(corsa, f)]
    if registrati:
        return NON_CONFERMATA, "nel registro: %s" % ", ".join(registrati)
    dette = [POSTI[c] for c in ("regolaphp", "annidato")
             if nella_risposta(corsa, c)]
    if dette:
        return NON_CONFERMATA, "nella risposta la parola di: %s" % ", ".join(
            dette)
    if not nella_risposta(corsa, "radice"):
        return NON_DISTINGUIBILE, SENZA_RADICE
    return CONFERMATA, ("nessuna delle due nel registro, nessuna delle due "
                        "parole nella risposta")


def giudica_dopo_lettura(corsa: Corsa, letto: str, motivo: str,
                         caricato: str) -> Tuple[str, str]:
    """Un caricamento che deve seguire il Read di un file: regola e
    annidato."""
    tentati = [x for x in corsa.letture if corsa_letto(x, letto)]
    if not tentati:
        return NON_DISTINGUIBILE, "Claude non ha letto %s" % letto
    if not any(x.riuscito for x in tentati):
        return NON_DISTINGUIBILE, "il Read di %s non è riuscito" % letto
    if not any(c.trigger_file_path == letto
               for c in caricati(corsa, motivo, caricato)):
        return NON_CONFERMATA, ("dopo il Read di %s nessun %s di %s con "
                                "trigger %s"
                                % (letto, motivo, caricato, letto))
    return CONFERMATA, "Read di %s, poi %s di %s con trigger %s" % (
        letto, motivo, caricato, letto)


def corsa_letto(lettura: Lettura, rel: str) -> bool:
    return corrisponde(lettura.percorso, rel)


def verdetto(chiave: str, corsa: Corsa, tipo: str) -> Tuple[str, str]:
    if chiave == "avvio":
        return giudica_avvio(corsa)
    if chiave == "import":
        return giudica_import(corsa)
    if chiave == "backtick":
        return giudica_backtick(corsa, tipo == "avvio")
    if chiave == "commento":
        return giudica_commento(corsa)
    if chiave == "su_richiesta":
        return giudica_su_richiesta(corsa)
    if chiave == "regola":
        return giudica_dopo_lettura(corsa, LETTURA_PHP, "path_glob_match",
                                    REGOLA_PHP)
    return giudica_dopo_lettura(corsa, LETTURA_SUB, "nested_traversal",
                                ANNIDATO)


def risposta_breve(testo: str) -> str:
    risposta = " ".join(testo.split())
    return risposta[:119] + "…" if len(risposta) > 120 else risposta


def riga_consumo(corsa: Corsa) -> str:
    return "prima richiesta %s token; turni %d; token %s; %s s" % (
        migliaia(corsa.prima_richiesta), corsa.turni, migliaia(corsa.token),
        in_secondi(corsa.secondi))


def stampa_corsa(tipo: str, n: int, corsa: Corsa) -> None:
    """Le righe dei dati di una chiamata di avvio o di lettura."""
    print("%s, %d: risposta «%s»; strumenti: %s; %s" % (
        tipo, n, risposta_breve(corsa.testo),
        ", ".join(corsa.strumenti) or "nessuno", riga_consumo(corsa)))
    print("  caricamenti: %s" % ("; ".join(riga_caricamento(c)
                                          for c in corsa.caricamenti)
                                 or "nessuno"))
    print("  parole nella risposta: %s" % "; ".join(
        "%s %s" % (POSTI[c], si_no(nella_risposta(corsa, c)))
        for c in CHIAVI))


def numeri_delle_esecuzioni() -> List[int]:
    numeri = set()
    for nome in os.listdir(CARTELLA):
        fatto = RE_NOME.match(nome)
        if fatto:
            numeri.add(int(fatto.group(1)))
    return sorted(numeri)


def avviso(messaggio: str) -> None:
    sys.stderr.write("controlla_caricamento.py: %s\n" % messaggio)


def leggi_tutto(numeri: List[int], lc: object) -> Optional[Dict[str, Corsa]]:
    """Le chiamate per nome; None se una manca o non va (detto su STDERR)."""
    corse: Dict[str, Corsa] = {}
    mancanti = 0
    nomi = [("%s-%d" % (t, n), True) for n in numeri
            for t in ("avvio", "lettura")]
    nomi += [("costo-%s" % b, False) for b in BRACCI]
    for nome, con_parole in nomi:
        try:
            corse[nome] = leggi_corsa(nome, lc, con_parole)
        except Mancante as exc:
            avviso(str(exc))
            mancanti += 1
    return None if mancanti else corse


def stampa_costi(corse: Dict[str, Corsa]) -> None:
    """I bracci di costo, come dati."""
    prima = {b: corse["costo-%s" % b].prima_richiesta for b in BRACCI}
    print()
    for b in BRACCI:
        corsa = corse["costo-%s" % b]
        print("costo, %s: risposta «%s»; %s" % (b, risposta_breve(corsa.testo),
                                               riga_consumo(corsa)))
        print("  caricamenti: %s" % ("; ".join(riga_caricamento(c)
                                              for c in corsa.caricamenti)
                                     or "nessuno"))
    print("Come dato, la prima richiesta dei bracci di costo, «Rispondi solo: "
          "ok»: %s." % "; ".join("%s %s token" % (b, migliaia(prima[b]))
                                 for b in BRACCI))
    print("Come dato, il commento a blocco sul braccio base: %s token; lo "
          "stesso testo visibile (inline): %s." % (
              con_segno(prima["commento"] - prima["base"]),
              con_segno(prima["inline"] - prima["base"])))
    print("Come dato, l'import contro lo stesso testo incollato: %s token "
          "(import ≥ inline: %s)." % (
              con_segno(prima["import"] - prima["inline"]),
              si_no(prima["import"] >= prima["inline"])))


def riepilogo(etichetta: str, esiti: List[str]) -> str:
    confermate = esiti.count(CONFERMATA)
    riga = "%s: %s %d su %d" % (etichetta, CONFERMATA, confermate, len(esiti))
    for altro in (NON_CONFERMATA, NON_DISTINGUIBILE):
        if altro in esiti:
            riga += "; %s %d" % (altro, esiti.count(altro))
    return riga


def controlla(lc: object) -> int:
    """Il controllo nella cartella corrente: i dati, i verdetti, l'uscita."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    numeri = numeri_delle_esecuzioni()
    if not numeri:
        print(NESSUNA)
        return 1
    corse = leggi_tutto(numeri, lc)
    if corse is None:
        print(RIFARE)
        return 1
    esiti: Dict[str, List[str]] = {chiave: [] for chiave, _ in ETICHETTE}
    nomi = dict(ETICHETTE)
    for n in numeri:
        for tipo in ("avvio", "lettura"):
            stampa_corsa(tipo, n, corse["%s-%d" % (tipo, n)])
        for tipo in ("avvio", "lettura"):
            for chiave in PER_TIPO[tipo]:
                esito, perche = verdetto(chiave, corse["%s-%d" % (tipo, n)],
                                         tipo)
                esiti[chiave].append(esito)
                print("%s (%s, %d): %s (%s)" % (nomi[chiave], tipo, n, esito,
                                                perche))
        print()
    stampa_costi(corse)
    print()
    for chiave, etichetta in ETICHETTE:
        print(riepilogo(etichetta, esiti[chiave]))
    print("\nCome dato, tutte le %d chiamate: turni %d; token %s; %s s." % (
        len(corse), sum(c.turni for c in corse.values()),
        migliaia(sum(c.token for c in corse.values())),
        in_secondi(sum(c.secondi for c in corse.values()))))
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
